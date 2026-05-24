# Delta for Ontology

## ADDED Requirements

### Requirement: ACORD-aligned core node labels
The system SHALL model insurance domain entities as a Labeled Property
Graph using the following node labels: `Party`, `InsuranceProduct`,
`Policy`, `Clause`, `Subject`, `RiskPeril`, `Claim`. Each label MUST
carry a stable, opaque `id: String` property that is unique across the
graph and is decoupled from any business key.

#### Scenario: Required labels are present
- GIVEN an empty Neo4j 5.13+ instance configured with the project schema
- WHEN the schema bootstrap script is applied
- THEN uniqueness constraints exist for `Party.id`, `Policy.policy_number`,
      `Clause.id`, `Claim.id`
- AND a node created without `id` is rejected by the writer layer.

#### Scenario: Business key is separate from identity
- GIVEN a `Policy` node with `id="POL_102"` and `policy_number="POL-88122"`
- WHEN the policy number is corrected to `policy_number="POL-88123"`
- THEN the node `id` MUST NOT change
- AND inbound edges remain valid without rewrite.

### Requirement: Property data types and required fields
Each node label SHALL define a typed property contract:

- `Party`: `id`, `name`, `type ∈ {Individual, Organization}`,
  `acord_code?`, `lang?`
- `InsuranceProduct`: `id`, `product_name`, `line_of_business ∈ {L&A, P&C}`
- `Policy`: `id`, `policy_number`, `status`, `effective_date`,
  `expiration_date`
- `Clause`: `id`, `clause_type ∈ {Coverage, Exclusion, Limit}`, `title`,
  `text_content`, `lang`, `embedding: List<Float>` (dimension 1536)
- `Subject`: `id`, `subject_type ∈ {Person, Vehicle, Property}`,
  `description`
- `RiskPeril`: `id`, `name`, `icd_code?`, `aliases: List<String>`,
  `lang?`
- `Claim`: `id`, `claim_number`, `date_of_loss`, `amount_claimed: Decimal`

#### Scenario: Writer rejects invalid enums
- GIVEN a Party node with `type="Robot"`
- WHEN the writer attempts to MERGE the node
- THEN the write MUST fail with a schema validation error
- AND no node is created.

#### Scenario: Embedding dimension enforced
- GIVEN the vector index is configured for 1536 dimensions
- WHEN a Clause is written with a 1024-dimensional embedding
- THEN the writer MUST reject the payload before reaching Neo4j.

### Requirement: Relationship catalogue
The graph SHALL only contain relationships from the closed set below,
each with the prescribed start/end labels and properties:

- `(:Party)-[:BUYS {role}]->(:Policy)`
- `(:Policy)-[:BASED_ON]->(:InsuranceProduct)`
- `(:InsuranceProduct)-[:CONTAINS]->(:Clause)`
- `(:Policy)-[:INSURES]->(:Subject)`
- `(:Clause)-[:COVERS {waiting_period_days, payout_ratio}]->(:RiskPeril)`
- `(:Clause)-[:EXCLUDES]->(:RiskPeril)`
- `(:Claim)-[:FILED_UNDER {file_date}]->(:Policy)`
- `(:Claim)-[:TRIGGERED_BY]->(:RiskPeril)`

Any other relationship type MUST be rejected at the writer boundary.

#### Scenario: Disallowed relationship rejected
- GIVEN a request to create `(:Party)-[:OWNS]->(:Claim)`
- WHEN the writer validates the payload
- THEN the request MUST be rejected with an "unknown relationship type"
      error.

### Requirement: Bitemporal endorseable edges
Every relationship whose semantics can be amended by a future
endorsement (initially `CONTAINS`, `COVERS`, `EXCLUDES`, `INSURES`,
`BUYS`) SHALL carry the temporal triple `valid_from: Date`,
`valid_to: Date | null`, `recorded_at: DateTime` and a boolean
`is_active`. Updates MUST be append-only: a superseded edge keeps its
original `valid_from`, gets `valid_to` set, `is_active=false`, and a new
edge is written for the new state.

#### Scenario: Endorsement preserves history
- GIVEN a `[:CONTAINS]` edge with `valid_from=2024-01-01`,
        `valid_to=null`, `is_active=true`
- WHEN an endorsement effective `2025-06-01` replaces the clause
- THEN the original edge has `valid_to=2025-05-31`, `is_active=false`
- AND a new `[:CONTAINS]` edge exists with `valid_from=2025-06-01`,
      `is_active=true`
- AND an "as-of 2025-01-15" traversal still returns the original clause.

### Requirement: Provenance on extracted entities
Every node and edge written by the LLM extraction pipeline SHALL carry
`source_doc_id`, `source_page`, `extractor_version` and
`confidence ∈ [0,1]` as properties. Nodes created from structured ETL
SHALL carry `source_system` and `source_record_id`.

#### Scenario: Confidence is queryable
- GIVEN a Clause extracted with `confidence=0.72`
- WHEN an operator queries Clauses with `confidence < 0.8`
- THEN the Clause is returned.

### Requirement: Identifier prefix convention
Internal `id` values SHALL be opaque strings prefixed by label:
`P_` (Party), `PROD_` (InsuranceProduct), `POL_` (Policy), `CL_`
(Clause), `SUB_` (Subject), `PER_` (RiskPeril), `CLM_` (Claim).

#### Scenario: Prefix mismatch rejected
- GIVEN a Policy node payload with `id="P_900"`
- WHEN the writer validates the payload
- THEN the write MUST be rejected.

### Requirement: Multilingual perils with alias set
`RiskPeril` SHALL be deduplicated across locales by ICD code first, then
by normalized name + alias set. The canonical node MUST store the
preferred display name in `name` and all locale variants under
`aliases`.

#### Scenario: Bilingual alias merging
- GIVEN an existing `RiskPeril {name:"急性心肌梗塞", icd_code:"I21.9"}`
- WHEN extractor proposes `RiskPeril {name:"Acute Myocardial Infarction",
        icd_code:"I21.9"}`
- THEN the resolver MUST MERGE on `icd_code`
- AND the English name is appended to `aliases`
- AND no second `RiskPeril` node is created.
