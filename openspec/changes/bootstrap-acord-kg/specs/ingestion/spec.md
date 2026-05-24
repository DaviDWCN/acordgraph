# Delta for Ingestion

## ADDED Requirements

### Requirement: Dual-track ingestion
The system SHALL support two ingestion tracks that converge on the same
graph schema:
1. **Structured track** — batch / CDC ETL from core policy admin and CRM
   systems. Mappings MUST be declarative (config-driven) and produce
   idempotent `MERGE` Cypher.
2. **Unstructured track** — LLM-driven extraction from PDF / DOCX policy
   wordings, claim forms and endorsements.

#### Scenario: Same Policy via both tracks reconciles
- GIVEN a Policy `POL_102` already present from the structured track
- WHEN the unstructured track surfaces references to the same
        `policy_number`
- THEN the resolver MUST link to the existing node
- AND no duplicate Policy is created.

### Requirement: Idempotent upserts
All writers SHALL use `MERGE` on stable identifiers. Re-running the
same input batch MUST be a no-op on graph state (excluding
`recorded_at`).

#### Scenario: Replay produces no diffs
- GIVEN a batch B1 already applied
- WHEN B1 is replayed
- THEN the resulting graph diff is empty for node and edge counts
- AND only audit fields (e.g., `recorded_at`) may change.

### Requirement: Heading-aware chunking
The PDF chunker SHALL respect document headings and clause boundaries.
Chunks MUST be ≤ 1500 tokens with ≤ 15% overlap, and MUST carry
`source_doc_id`, `source_page`, and a `path` such as
`"§3.2 / Exclusions"`.

#### Scenario: Clause is not split mid-sentence
- GIVEN a clause that begins on page 4 and ends on page 5
- WHEN the chunker processes the document
- THEN at least one chunk contains the full clause body
- AND no chunk ends mid-sentence within a heading section.

### Requirement: JSON-Schema-constrained extraction
The LLM extractor SHALL use structured-output decoding bound to
`assets/schemas/extraction.schema.json`. Outputs that fail schema
validation SHALL be retried once with a corrective message, then
quarantined.

#### Scenario: Invalid output is quarantined
- GIVEN an LLM response missing the required `edges` array
- WHEN one retry also fails validation
- THEN the payload is written to the quarantine queue with the raw
      response, source reference and validator error
- AND no graph mutation occurs.

### Requirement: Entity resolution pipeline
Before writing extracted `RiskPeril` and `Party` nodes the resolver
SHALL apply the cascade:
1. Exact match on a controlled key (`icd_code`, `acord_code`,
   normalized national-id hash).
2. Cosine similarity on the entity-name embedding against existing
   nodes. Match if `cosine ≥ 0.89`.
3. If `0.80 ≤ cosine < 0.89`, route to a **Human-in-the-loop** review
   queue with both candidates.
4. Otherwise create a new node.

#### Scenario: High-confidence merge
- GIVEN existing peril `PER_401 {name:"急性心肌梗塞", icd_code:"I21.9"}`
- WHEN extractor emits `{name:"心肌梗死", icd_code:"I21.9"}`
- THEN the resolver merges via step 1 (icd_code)
- AND appends `"心肌梗死"` to `PER_401.aliases`.

#### Scenario: Ambiguous proposal sent to review
- GIVEN no exact-key match exists
- AND the cosine similarity is 0.84
- WHEN the resolver evaluates the candidate
- THEN the proposal is written to the review queue
- AND no graph node is created until a reviewer decides.

### Requirement: Provenance and confidence
Every extracted node and edge SHALL include `source_doc_id`,
`source_page`, `extractor_version`, and `confidence`. The writer SHALL
reject payloads missing any of these fields.

#### Scenario: Missing provenance is rejected
- GIVEN an extractor payload without `source_doc_id`
- WHEN the writer validates the payload
- THEN the write MUST fail with a "missing provenance" error.

### Requirement: Embedding generation
`Clause.embedding` SHALL be produced by a configured embedding model
whose output dimension matches the vector index (1536). The embedding
input MUST be the chunk text after light normalization (whitespace
collapse, no semantic rewriting).

#### Scenario: Dimension mismatch is rejected
- GIVEN the vector index is configured at dimension 1536
- WHEN the embedding model is swapped to one producing 768-d vectors
- THEN the ingestion job MUST refuse to start
- AND surface a configuration error referencing the index.
