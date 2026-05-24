# Delta for Governance & QA (PII hardening + currency)

## MODIFIED Requirements

### Requirement: PII tokenisation
Personally identifiable fields SHALL be tokenised wherever they may
be carried in the knowledge graph or its directly attached stores:

- `Party.*` PII fields (legal name, national id, date of birth,
  contact) — as in v1.
- `PersonSubject.*` — `national_id_token`, `dob_year` only; full DOB
  forbidden.
- `Chunk.text` — redacted with the same tokeniser used for `Party`
  PII; raw chunk text lives only in the secure document store.
- `Document.filename` — tokenised at ingest; raw filename in the
  document store.
- `Clause.text_content` — redacted form is what is stored in the
  graph; the verbatim original lives in the document store and is
  joined at serving with row-level authorisation.

Raw PII MUST NOT be stored in Neo4j; tokens MUST be resolvable only
through a separate, access-controlled vault. A graph export MUST
contain zero PII fields in clear form.

#### Scenario: Chunk export carries no PII
- GIVEN a `Chunk` whose source paragraph names a person
- WHEN the graph is exported
- THEN the chunk text contains the tokeniser's placeholder (e.g.,
       `<PERSON_4f7a>`) and not the original name.

#### Scenario: Filename leak prevented
- GIVEN a source PDF named `Zhang_San_Health.pdf`
- WHEN the `Document` node is created
- THEN `Document.filename` stores a redacted form
- AND a separate vault entry maps it to the original filename for
       entitled callers.

## ADDED Requirements

### Requirement: Embedding-inversion defence
Every embedding indexed in Neo4j (vector index over `Clause.embedding`
and any future embedding) MUST be derived from the PII-**redacted**
form of the input text. The pipeline MUST refuse to emit an embedding
computed over raw text. Whenever the redaction policy changes
(tokeniser version, new PII entity types), an OpenSpec change MUST
schedule a full re-embedding before retrieval clients consume the
new index.

#### Scenario: Re-embedding on policy change
- GIVEN the PII tokeniser is upgraded from `v1` to `v2`
- WHEN the change is applied
- THEN a tracked OpenSpec change schedules re-embedding for every
       `Clause` ingested before the upgrade
- AND the retrieval layer continues to read the v1 index until the
       v2 re-embedding is complete.

#### Scenario: Vector index is not publicly readable
- GIVEN an unauthenticated caller
- WHEN the caller attempts to enumerate vectors
- THEN the request MUST be rejected
- AND no embedding fragment leaves the serving layer.

### Requirement: Currency policy
Every monetary attribute SHALL be stored together with its native ISO
4217 `currency` code. Retrieval and serving MUST NOT silently convert
across currencies. `/v1/answer` MAY accept an optional
`convert_to: <ISO4217>` request flag; when set, the response MUST
include:

- `fx_source: String`
- `fx_rate: Number`
- `fx_as_of: DateTime`
- A structured `disclaimer: String` stating that a currency conversion
  was applied.

Cross-currency aggregations (e.g., total claims paid across
currencies) MUST refuse to execute without an explicit `convert_to`
and MUST surface the same `fx_*` block.

#### Scenario: No silent conversion
- GIVEN a claim stored as `amount_claimed=50000.0, currency="CNY"`
- WHEN `/v1/answer` is called without `convert_to`
- THEN the response cites the amount as `50000.0 CNY`
- AND no `fx_*` field is present.

#### Scenario: Conversion is auditable
- GIVEN the same claim with the request `convert_to="USD"`
- WHEN the answer is rendered
- THEN `fx_source`, `fx_rate`, `fx_as_of`, and `disclaimer` are
       present
- AND the structured `disclaimer` is included in the
       `latency_ms_breakdown` envelope's audit log.
