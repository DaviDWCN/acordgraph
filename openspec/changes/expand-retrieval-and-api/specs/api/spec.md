# Delta for API Contract

## MODIFIED Requirements

### Requirement: Public endpoint surface
The serving layer SHALL expose at minimum:

- `POST /v1/resolve` — resolve free-text entities to graph ids.
- `POST /v1/answer` — execute the full GraphRAG pipeline and return a
  grounded answer with citations.
- `POST /v1/explain` — return the Cypher path(s) and the retrieved
  sub-graph that supported a given `answer_id`.
- `POST /v1/ingest` — idempotent write endpoint for both extraction
  payloads and ETL batches.
- `POST /v1/feedback` — capture user / HITL corrections against a
  prior `answer_id`.
- `GET  /v1/lineage/{node_id}` — drill-down for a node to its source
  document / record.
- `GET  /v1/health` — readiness/liveness, including index health.

#### Scenario: Ingest is idempotent under retries
- GIVEN a POST `/v1/ingest` with `Idempotency-Key=K1` is processed
- WHEN the same key is replayed within 24 h
- THEN the server returns the original `ingest_id`
- AND no second mutation occurs.

#### Scenario: Lineage requires entitlement
- GIVEN caller C has no entitlement to view `CL_502`
- WHEN C calls `GET /v1/lineage/CL_502`
- THEN the response MUST be `404 Not Found`
- AND no document filename appears in the error body.

### Requirement: Answer payload shape
Responses from `/v1/answer` SHALL include the following required
fields:

- `answer_id`
- `answer_text`
- `verdict` ∈ {`COVERED`, `EXCLUDED`, `UNDETERMINED`}
- `resolution_layer` ∈ {`L1`, `L2`, `L3`, `L4`, `N/A`}
- `intent_id`
- `template_id`
- `as_of` (echoed, defaulted to "now" if absent in request)
- `citations: [{ clause_id, title, source_doc_id, source_page }]`
- `conflicting_clauses: [{ clause_id, layer, status }]`
- `reasoning_path: [Cypher segments]`
- `latency_ms_breakdown: { resolve, recall, rerank, cypher, llm, overhead }`
- `confidence_floor: number` — minimum extracted `confidence` across
  cited clauses.

#### Scenario: Confidence floor surfaced
- GIVEN cited clauses have extracted confidences 0.92 and 0.83
- WHEN the answer is rendered
- THEN `confidence_floor` MUST be 0.83.

#### Scenario: Empty citations forbidden
- GIVEN retrieval produced a non-empty sub-graph
- WHEN the answerer returns a payload with `citations=[]`
- THEN the serving layer MUST reject the response and regenerate.

## ADDED Requirements

### Requirement: Ingest write contract
`POST /v1/ingest` SHALL be all-or-nothing per request: a 2xx response
is returned only when every submitted item has been durably persisted
to the graph, durably written to the quarantine store, or durably
staged (`:Staged`). The response body MUST contain
`{ ingest_id, accepted, staged_count, quarantined_count, errors[] }`.
Partial success is not allowed; on any unrecoverable error mid-batch
the writer MUST roll back the already-persisted items in the same
request.

#### Scenario: Atomic batch
- GIVEN a batch with 50 nodes; the 47th fails a writer-side validation
- WHEN the writer cannot recover within the retry budget
- THEN no node from this batch remains in the graph
- AND the response is 4xx with `errors[]` describing the failing item.

### Requirement: Feedback capture
`POST /v1/feedback` SHALL persist user / HITL corrections in a
governance-owned store, keyed by `answer_id`. The endpoint MUST NOT
mutate graph state. Feedback rows MUST be eligible for inclusion in
the next golden-set refresh; the refresh process is owned by the
governance harness (see `governance/spec.md`).

#### Scenario: Feedback is non-mutating
- GIVEN a feedback row reports that `CL_502` was wrongly cited
- WHEN the endpoint accepts the row
- THEN the graph is unchanged
- AND the row appears in the feedback store for the next golden-set
       triage.

### Requirement: Lineage endpoint contract
`GET /v1/lineage/{node_id}` SHALL execute the `lineage_drilldown`
template from the Cypher catalogue and return:

```
{
  "node_id":        "...",
  "label":          "Clause",
  "lineage": [
    { "type": "Chunk",     "id": "...", "page": 4, "path": "§3.2" },
    { "type": "Document",  "id": "...", "filename": "...", "sha256": "..." }
  ]
}
```

For structured-ETL-origin nodes the lineage list contains a single
`{ "type": "Record", "source_system": "...", "source_record_id": "..." }`
entry.

#### Scenario: ETL lineage
- GIVEN `POL_102` was ingested from core system `PAS`
- WHEN `GET /v1/lineage/POL_102` is called
- THEN the response lineage list contains exactly one entry of type
       `Record` with `source_system="PAS"`.
