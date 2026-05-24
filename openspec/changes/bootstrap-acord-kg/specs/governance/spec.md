# Delta for Governance & QA

## ADDED Requirements

### Requirement: PII tokenisation
Personally identifiable fields on `Party` (legal name, national id,
date of birth, contact) SHALL be tokenised at ingest. Raw PII MUST NOT
be stored in the graph; tokens MUST be resolvable only through a
separate, access-controlled vault.

#### Scenario: Graph backup contains no raw PII
- GIVEN a database export of the graph
- WHEN any `Party` node is inspected
- THEN no field contains a national id, full date of birth, address or
      phone number in clear form.

### Requirement: Endorsement event traceability
Every change to an endorseable edge SHALL be linked to an
`Endorsement` event node carrying `id`, `effective_date`,
`reason_code`, `actor`. The superseded and superseding edges MUST both
reference the same `Endorsement` event.

#### Scenario: Audit trail of a coverage change
- GIVEN an endorsement event E1 effective 2025-06-01
- WHEN the operator inspects the change history of policy POL_102
- THEN both the closed (`is_active=false`) and the new
      (`is_active=true`) `[:CONTAINS]` edges link back to E1.

### Requirement: Evaluation harness gating
A versioned golden set of question → expected-sub-graph examples SHALL
exist. CI MUST run the harness on every change touching prompts,
schema, ontology or retrieval logic, and MUST fail the build if any of:

- `recall@5` drops by more than 2 absolute points,
- `citation_precision` falls below 0.95,
- `faithfulness` (per Ragas) falls below 0.90.

#### Scenario: Regression blocks merge
- GIVEN the baseline `citation_precision` is 0.97
- WHEN a change lowers it to 0.93
- THEN CI marks the run as failed
- AND the change cannot be archived until the metric is restored.

### Requirement: Quarantine and replay
All ingestion errors (schema-invalid extractor outputs, ER conflicts,
provenance-missing payloads) SHALL be persisted in a quarantine store
with the raw input and reason. Operators MUST be able to replay
quarantined items after fixing the upstream issue without manual data
surgery.

#### Scenario: Replay after fix
- GIVEN 12 documents quarantined due to a prompt bug
- WHEN the prompt is corrected and a replay job is started
- THEN the 12 documents are re-extracted and, on success, written to
      the graph
- AND the quarantine entries are marked resolved with the new run id.

### Requirement: Confidence-aware promotion
Extracted nodes/edges with `confidence < 0.6` MUST NOT be served to
retrieval. They MAY be stored under a separate label / property flag
for staging and review only.

#### Scenario: Low-confidence clause not surfaced
- GIVEN a Clause stored with `confidence=0.55`
- WHEN the retriever performs hybrid recall
- THEN this Clause MUST NOT appear in the candidate list.

### Requirement: Lineage
For any node or edge returned at serving time, the system MUST be able
to surface, in O(1) hops, the originating source document or source
system record.

#### Scenario: Drill-down from an answer
- GIVEN an answer citing Clause CL_502
- WHEN an operator follows the lineage link
- THEN the original PDF file and page number are displayed.
