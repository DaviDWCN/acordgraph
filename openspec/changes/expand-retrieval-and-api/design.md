# Design: Expand Retrieval & API Surface

## 1. Cypher Template Catalogue

### 1.1 Directory layout
```
assets/cypher/
├── catalog.yaml                              # manifest of intent ↔ template
├── templates/
│   ├── coverage_judgment.cypher              # was: 10_graphrag_lookup.cypher
│   ├── product_clause_list.cypher
│   ├── product_exclusion_list.cypher
│   ├── policy_endorsement_history.cypher
│   ├── claims_by_policy.cypher
│   ├── claims_open_for_party.cypher
│   ├── coverage_diff_between_dates.cypher
│   ├── peril_resolve.cypher                  # used by /v1/resolve
│   └── lineage_drilldown.cypher
└── tests/
    └── golden/<intent_id>.json               # one golden in/out per template
```

`catalog.yaml` row shape:

```yaml
- intent_id: coverage_judgment
  template: templates/coverage_judgment.cypher
  parameters:
    party_id:             { type: string,        required: true }
    retrieved_clause_ids: { type: [string],      required: true }
    target_peril_name:    { type: string,        required: true }
    as_of:                { type: date,          required: false }
  bitemporal: true
  expected_return: rows
  golden: tests/golden/coverage_judgment.json
```

### 1.2 Intent → template resolution
The resolver layer maps an LLM-classified `intent_id` to exactly one
template id. The execution layer is a thin parameterised runner; it
MUST reject:
- unknown `intent_id`s,
- parameter sets that do not match the manifest contract,
- any free-form Cypher string supplied at runtime.

When intent classification is ambiguous (top-2 within 0.05), the API
MUST return a `clarification` payload rather than guess.

### 1.3 Adding a template
A new template lands via an OpenSpec change that:
1. Appends to `catalog.yaml`.
2. Adds the `.cypher` file under `templates/`.
3. Adds at least one golden case under `tests/golden/`.
4. Updates the test harness configuration.

The change MUST NOT be archived if any of the four steps is missing.

## 2. Coverage / Exclusion precedence layers

Resolution order from highest precedence to lowest:

| Layer | Source                                       | Effect                              |
|------:|----------------------------------------------|-------------------------------------|
| L1    | `Endorsement` introducing reinstated cover    | OVERRIDES exclusion                 |
| L2    | Rider product clause covering the peril       | OVERRIDES base-product exclusion    |
| L3    | Base-product `:EXCLUDES` clause               | OVERRIDES base-product `:COVERS`    |
| L4    | Base-product `:COVERS` clause                 | Effective when L1-L3 silent         |

Within the same layer, ties are broken by `recorded_at DESC`. The
answerer MUST emit:
- `verdict` ∈ {`COVERED`, `EXCLUDED`, `UNDETERMINED`},
- `resolution_layer ∈ {L1, L2, L3, L4}`,
- the full `conflicting_clauses[]` list with each clause's layer.

This makes the audit reviewable: regulators see *why* a verdict won,
not just that it did.

## 3. API additions

### 3.1 `POST /v1/ingest`
- Body: a profile-bound extraction payload (see Change 2) **or** a
  structured-ETL batch envelope.
- Headers: `Idempotency-Key` (required), `Content-Type`,
  `X-Profile: wording|claim-form|endorsement|etl`.
- Response: `{ ingest_id, accepted, staged_count, quarantined_count,
  errors[] }`.
- 2xx is returned only when the writer has durably persisted (or
  durably quarantined) every item; partial success is **not** allowed.

### 3.2 `POST /v1/feedback`
- Body: `{ answer_id, verdict_correct: bool, corrected_clause_ids?:
  [string], comment?: string, reporter: string }`.
- Effect: persists a feedback row, eligible for inclusion in the next
  golden-set refresh.
- Does NOT mutate graph state.

### 3.3 `GET /v1/lineage/{node_id}`
- Effect: executes `lineage_drilldown.cypher` for the given node id.
- Response: ordered list of lineage rows (`Document`, `Chunk`,
  `source_system`, `source_record_id` …).
- Requires the same row-level authorisation as `/v1/answer`.

### 3.4 Answer payload extension
The existing required fields stay. Add (all required):
- `intent_id`
- `template_id`
- `as_of` (echoed back, even if defaulted)
- `confidence_floor` — the minimum extracted `confidence` across cited
  clauses; clients use this to flag answers built on near-staged data.
- `resolution_layer` — see §2.

## 4. Metric definitions

| Metric                  | Definition                                                                                                  |
|-------------------------|-------------------------------------------------------------------------------------------------------------|
| `recall@5`              | For each Q in the golden set, fraction of `expected_clause_ids` present in the top-5 reranked candidates. Average over Q. |
| `citation_precision`    | For each answer, `|cited_ids ∩ retrieved_subgraph_clause_ids| / |cited_ids|`. Average over answered Q.       |
| `faithfulness`          | Ragas `faithfulness` against `retrieved_subgraph_text`.                                                     |
| `subgraph_overlap_f1`   | F1 between produced sub-graph (node-id set) and expected sub-graph. Weighted by clause / peril / coverage.  |

### 4.1 Baseline freezing
- The baseline is the metric vector from the most recent change that
  was archived **after** running the harness clean.
- A change PR MUST run the harness with deterministic seeds (fixed
  embedding cache, fixed reranker checkpoint, fixed LLM temperature=0,
  fixed sampling seed) and fail if any of:
  - `recall@5` drops by more than 0.02 absolute points,
  - `citation_precision` falls below 0.95,
  - `faithfulness` falls below 0.90,
  - `subgraph_overlap_f1` drops by more than 0.03 absolute points.
- Baseline updates ("roll-forward") MUST be an explicit checkbox in
  the change PR, justifying every metric move.

## 5. Open Questions (parked)

1. Should `intent_id` classification be done by the LLM or by a small
   discriminative classifier? Either satisfies the contract; defer to
   benchmarking.
2. Where does the golden set live operationally — in this repo
   (`assets/eval/`) or a separate audit-controlled repo? Will be
   resolved when audit signs off the eval governance.
