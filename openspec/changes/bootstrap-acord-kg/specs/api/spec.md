# Delta for API Contract

## ADDED Requirements

### Requirement: Public endpoint surface
The serving layer SHALL expose at minimum the following logical
endpoints (transport / framework is not prescribed at this stage):

- `POST /v1/resolve` — resolve free-text entities to graph ids
  (`party_id`, `policy_id`, `product_id`, `peril_id`).
- `POST /v1/answer` — execute the full GraphRAG pipeline and return a
  grounded answer with citations.
- `POST /v1/explain` — return the Cypher path(s) and the retrieved
  sub-graph that supported a given answer id.
- `GET  /v1/health` — readiness/liveness, including index health.

#### Scenario: Health surfaces index status
- GIVEN the Neo4j vector index is in `POPULATING` state
- WHEN `GET /v1/health` is called
- THEN the response indicates `status=degraded`
- AND lists the affected index.

### Requirement: Answer payload shape
Responses from `/v1/answer` SHALL include:
`answer_id`, `answer_text`, `citations: [{clause_id, title,
source_doc_id, source_page}]`, `reasoning_path: [Cypher segments]`,
`as_of`, `latency_ms_breakdown`.

#### Scenario: Empty citations forbidden
- GIVEN the retrieval produced a non-empty sub-graph
- WHEN the answerer returns a payload with `citations=[]`
- THEN the serving layer rejects the response and regenerates.

### Requirement: Latency budgets
The end-to-end p95 latency for `/v1/answer` SHALL be ≤ **1.5 s** under
nominal load (≤ 50 RPS), allocated approximately as:

| Stage             | p95 budget |
|-------------------|-----------:|
| Resolve           | 80 ms      |
| Vector + Lexical  | 150 ms     |
| Rerank            | 200 ms     |
| Cypher traversal  | 120 ms     |
| LLM grounded gen  | 900 ms     |
| Overhead          | 50 ms      |

Concrete numbers MAY be tuned in a future change; the stage breakdown
contract MUST be preserved.

#### Scenario: Budget surfaced for ops
- GIVEN a successful `/v1/answer` response
- WHEN the operator inspects `latency_ms_breakdown`
- THEN keys for `resolve`, `recall`, `rerank`, `cypher`, `llm`,
      `overhead` are present.

### Requirement: Idempotency and tracing
All write endpoints SHALL accept an `Idempotency-Key` header. All
endpoints SHALL emit OpenTelemetry spans named per stage
(`acordgraph.resolve`, `acordgraph.recall`, `acordgraph.rerank`,
`acordgraph.cypher`, `acordgraph.answer`).

#### Scenario: Replay-safe ingestion
- GIVEN a write request with `Idempotency-Key: K1` is processed
- WHEN the same request is retried with the same key within 24 h
- THEN the server returns the original response
- AND no second mutation occurs.

### Requirement: Authentication & authorisation
Endpoints SHALL require authenticated callers. Row-level authorisation
MUST restrict `Party`-scoped responses to callers entitled to that
party's data. Unauthorised access MUST NOT leak existence of a party
(return 404, not 403, for missing entitlement).

#### Scenario: Existence not leaked
- GIVEN caller C without entitlement to party `P_001`
- WHEN C calls `/v1/answer` with a question that resolves to `P_001`
- THEN the response is `404 Not Found`
- AND no party identifier appears in the error body.

### Requirement: API versioning
Breaking changes to request / response shape SHALL bump the URL major
version (`/v1/` → `/v2/`). Minor additive fields MUST be backwards
compatible.

#### Scenario: Additive field is backwards compatible
- GIVEN a client built against `/v1/answer` v1.0
- WHEN the server adds a new optional field `confidence` to the
        response
- THEN the existing client continues to parse responses successfully.
