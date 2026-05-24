# Delta for Ontology

## MODIFIED Requirements

### Requirement: ACORD-aligned core node labels
The system SHALL model insurance domain entities as a Labeled Property
Graph using the following node labels: `Party`, `InsuranceProduct`,
`Policy`, `Clause`, `Subject`, `RiskPeril`, `Claim`, **`Endorsement`**,
**`PolicyState`**, **`PartyState`**, **`RiskPerilState`**, and the
**optional reified `Coverage`** node (see "Coverage reification
trigger" below). Each label MUST carry a stable, opaque `id: String`
property that is unique across the graph and is decoupled from any
business key.

#### Scenario: Endorsement is part of the closed catalogue
- GIVEN a writer payload to MERGE `(:Endorsement {id:"END_001",
        effective_date:"2025-06-01", reason_code:"RIDER_ADD",
        actor:"agent_42"})`
- WHEN the writer validates the payload
- THEN the node MUST be accepted
- AND a uniqueness constraint on `Endorsement.id` MUST exist.

#### Scenario: State nodes are first-class
- GIVEN a `Policy` whose `status` changed from `Pending` to `InForce`
        on 2024-03-12
- WHEN history is materialised
- THEN two `PolicyState` nodes exist, each linked
       `(:Policy)-[:HAS_STATE]->(:PolicyState)` with disjoint
       `[valid_from, valid_to]` ranges
- AND only one state has `is_active=true`.

### Requirement: Property data types and required fields
Each node label SHALL define a typed property contract:

- `Party`: `id`, `name`, `type ∈ {Individual, Organization}`,
  `acord_code?`, `lang?`
- `InsuranceProduct`: `id`, `product_name`, `line_of_business ∈ {L&A, P&C}`
- `Policy`: `id`, `policy_number`, **`status` (denormalised latest),**
  `effective_date`, `expiration_date`
- `Clause`: `id`, `clause_type ∈ {Coverage, Exclusion, Limit}`, `title`,
  `text_content`, `lang`, `embedding: List<Float>` (dimension
  configured by the active embedding profile; default 1536)
- `Subject` (super-label, always paired with one subtype):
  `id`, `subject_type ∈ {Person, Vehicle, Property}`, `description`
  - `PersonSubject` (secondary): `national_id_token`, `dob_year`,
    `gender?`
  - `VehicleSubject` (secondary): `vin`, `plate_number?`, `make?`,
    `model?`, `manufacture_year?`
  - `PropertySubject` (secondary): `address_token`, `property_type`,
    `gps_geohash?`
- `RiskPeril`: `id`, `name`, **`code_system?`**, **`code_value?`**,
  `aliases: List<String>`, `lang?` *(read-through alias `icd_code` is
  derived when `code_system='ICD-10'`)*
- `Claim`: `id`, `claim_number`, `date_of_loss`,
  `amount_claimed: Decimal`, **`currency: String` (ISO 4217)**,
  **`report_date: Date`**, **`incident_location?: String`**
- **`Endorsement`**: `id` (prefix `END_`), `effective_date`,
  `recorded_at`, `reason_code`, `actor`, `source_doc_id?`,
  `confidence?`
- **`PolicyState` / `PartyState` / `RiskPerilState`**: `id`
  (`<parent_id>_v<n>`), `valid_from`, `valid_to: Date|null`,
  `recorded_at`, plus the subset of parent properties that vary over
  time

#### Scenario: Subtype required field enforced
- GIVEN a `Subject` MERGE payload with secondary label `VehicleSubject`
        but no `vin`
- WHEN the writer validates the payload
- THEN the write MUST be rejected with a "missing required field for
        subtype" error.

#### Scenario: Currency pairing enforced on money
- GIVEN a `Claim` payload with `amount_claimed=50000.0` and no
        `currency`
- WHEN the writer validates the payload
- THEN the write MUST be rejected.

### Requirement: Relationship catalogue
The graph SHALL only contain relationships from the closed set below,
each with the prescribed start/end labels and properties:

- `(:Party)-[:BUYS {role, share_pct?, relationship_to_insured?}]->(:Policy)`
- `(:Policy)-[:BASED_ON]->(:InsuranceProduct)`
- `(:InsuranceProduct)-[:CONTAINS]->(:Clause)`
- `(:InsuranceProduct)-[:RIDES_ON]->(:InsuranceProduct)` *(rider
  attachment; the rider is the start node)*
- `(:Policy)-[:INSURES {sum_insured?, currency?, deductible?}]->(:Subject)`
- `(:Clause)-[:COVERS {waiting_period_days, payout_ratio}]->(:RiskPeril)`
- `(:Clause)-[:EXCLUDES]->(:RiskPeril)`
- `(:Claim)-[:FILED_UNDER {file_date}]->(:Policy)`
- `(:Claim)-[:TRIGGERED_BY]->(:RiskPeril)`
- `(:Claim)-[:ON_SUBJECT]->(:Subject)`
- `(:Policy)-[:HAS_STATE]->(:PolicyState)`
- `(:Party)-[:HAS_STATE]->(:PartyState)`
- `(:RiskPeril)-[:HAS_STATE]->(:RiskPerilState)`
- `(:Endorsement)-[:AMENDS]->(:Policy)`
- `(:Endorsement)-[:SUPERSEDES]->(:Clause)`
- `(:Endorsement)-[:SUPERSEDES]->(:Coverage)`
- `(:Endorsement)-[:INTRODUCES]->(:Clause)`
- `(:Endorsement)-[:INTRODUCES]->(:Coverage)`

When the reified `Coverage` node is used (see "Coverage reification
trigger") the chain `(:Clause)-[:COVERS]->(:RiskPeril)` is replaced by
`(:Clause)-[:HAS_COVERAGE]->(:Coverage)-[:FOR_PERIL]->(:RiskPeril)`
and the runtime numbers move to the `Coverage` node.

Any other relationship type MUST be rejected at the writer boundary.

#### Scenario: Endorsement audit pair
- GIVEN endorsement `END_001` amends `POL_102` effective 2025-06-01
- WHEN the writer processes the endorsement
- THEN the closed `[:CONTAINS]` edge and the new `[:CONTAINS]` edge
       both carry property `endorsement_id="END_001"`
- AND `(END_001)-[:SUPERSEDES]->` and `(END_001)-[:INTRODUCES]->` edges
       exist pointing at the respective `Clause` (or `Coverage`) endpoints
- AND `(END_001)-[:AMENDS]->(POL_102)` exists.

#### Scenario: Claim points at a subject
- GIVEN policy `POL_FLEET_01` insures three `VehicleSubject` nodes
- WHEN a claim is filed for vehicle `SUB_VEH_2`
- THEN `(:Claim)-[:ON_SUBJECT]->(SUB_VEH_2)` MUST be written
- AND traversals from the claim to "the loss object" return exactly
       one `Subject`.

### Requirement: Bitemporal endorseable edges
Every relationship whose semantics can be amended by a future
endorsement (initially `CONTAINS`, `COVERS`, `EXCLUDES`, `INSURES`,
`BUYS`, `HAS_COVERAGE`, `FOR_PERIL`, `RIDES_ON`) SHALL carry the
temporal triple `valid_from: Date`, `valid_to: Date | null`,
`recorded_at: DateTime`. The boolean `is_active` IS a **derived**
property: writers MUST set
`is_active = (valid_to IS NULL OR valid_to > now())` in the same
transaction; readers MAY use either form. Updates MUST be append-only:
a superseded edge keeps its original `valid_from`, gets `valid_to`
set, and a new edge is written for the new state.

#### Scenario: Derived is_active invariant
- GIVEN an edge with `valid_to=2024-12-31` and today is 2025-03-01
- WHEN any reader inspects the edge
- THEN `is_active=false`
- AND any writer attempting to MERGE `is_active=true` on the same edge
       MUST be rejected.

### Requirement: Provenance on extracted entities
*(unchanged from `bootstrap-acord-kg`; included here for completeness
of the modified ontology spec — see that change's spec for the
authoritative text.)*

### Requirement: Identifier prefix convention
Internal `id` values SHALL be opaque strings prefixed by label:
`P_` (Party), `PROD_` (InsuranceProduct), `POL_` (Policy), `CL_`
(Clause), `SUB_` (Subject), `PER_` (RiskPeril), `CLM_` (Claim),
**`END_` (Endorsement)**, **`COV_` (Coverage when reified)**. State
nodes follow `<parent_id>_v<n>` (e.g., `POL_102_v3`).

#### Scenario: Endorsement prefix enforced
- GIVEN an `Endorsement` payload with `id="E_900"`
- WHEN the writer validates the payload
- THEN the write MUST be rejected.

### Requirement: Multilingual perils with alias set
`RiskPeril` SHALL be deduplicated across locales by `(code_system,
code_value)` first, then by normalized name + alias set. The canonical
node MUST store the preferred display name in `name` and all locale
variants under `aliases`.

#### Scenario: Cross-system alias merging
- GIVEN existing `RiskPeril {code_system:"ICD-10", code_value:"I21.9",
        name:"急性心肌梗塞"}`
- WHEN extractor proposes `{code_system:"ICD-10", code_value:"I21.9",
        name:"Acute Myocardial Infarction"}`
- THEN the resolver MUST MERGE on `(code_system, code_value)`
- AND the English name is appended to `aliases`.

## ADDED Requirements

### Requirement: Node-level temporality via state nodes
For each `Policy`, `Party`, and `RiskPeril` whose mutable attributes
(e.g., `status`, `name`, `aliases`) may change over time, the graph
SHALL retain the full history as `*_State` nodes linked via
`[:HAS_STATE]`. The parent node MUST carry a denormalised projection
of the **latest** active state for fast point reads. An "as-of"
attribute lookup for a historical date MUST be satisfiable in a
single hop from the parent.

#### Scenario: As-of attribute lookup
- GIVEN policy `POL_102` whose status moved
        `Pending → InForce → Lapsed`
- WHEN the retriever asks for the policy state as-of 2024-06-01
- THEN exactly one `PolicyState` is returned whose
       `valid_from ≤ 2024-06-01 ≤ coalesce(valid_to, 2024-06-01)`
- AND its `status` matches the value the policy held on that date.

### Requirement: Coverage reification trigger
A reified `Coverage` node MUST be used (replacing the
`[:COVERS]` edge) when **any** of the following hold for a
`(Product → Clause → RiskPeril)` chain:
1. An `Endorsement` overrides `payout_ratio` or
   `waiting_period_days` for a specific `Policy`.
2. A `Rider` product attached via `[:RIDES_ON]` changes those numbers.
3. Two `Policy` instances on the same product disagree on those
   numbers for the same `(Clause, RiskPeril)` pair.

In every other case the simple `[:COVERS]` edge form is retained. The
writer MUST detect the trigger condition and perform the reification
atomically — partial reification (some policies on the edge form,
others on the node form, for the same trigger) MUST be rejected.

#### Scenario: Endorsement overrides payout — reification fires
- GIVEN base coverage `payout_ratio=0.8` on `(CL_502)-[:COVERS]->(PER_401)`
- AND endorsement `END_001` on `POL_102` sets `payout_ratio=1.0`
- WHEN the writer applies the endorsement
- THEN the base `[:COVERS]` edge is replaced by `[:HAS_COVERAGE]->
       (:Coverage)-[:FOR_PERIL]->(PER_401)` for the affected policy chain
- AND the new `Coverage` node carries `payout_ratio=1.0` and links
       back to `END_001` via `[:INTRODUCES]`.

### Requirement: Generic peril coding
`RiskPeril` SHALL carry `code_system: String` and `code_value: String`.
The pair MUST be jointly indexed. Permitted `code_system` values are
`ICD-10`, `ICD-11`, `ACORD-CauseOfLoss`, `ACORDGRAPH-INTERNAL`. The
property `icd_code` MAY be exposed as a read-through alias derived
from `(code_system='ICD-10', code_value)` for backward compatibility.

#### Scenario: P&C peril without ICD
- GIVEN a P&C peril "Hailstorm" with no ICD code
- WHEN the writer MERGEs `{code_system:"ACORD-CauseOfLoss",
        code_value:"HAIL"}`
- THEN the write MUST succeed
- AND retrieval queries that filter by `(code_system, code_value)` MUST
       return the node.

### Requirement: ACORD class mapping is authoritative
A versioned mapping table at `docs/acord-mapping.md` SHALL list every
AIM v2.x class projected into acordgraph, the projection target
(label / property / edge), and an explicit "not modelled" row for
classes deliberately dropped. Any change that adds, renames, or
removes a label or relationship type MUST update this file in the
same OpenSpec change.

#### Scenario: Co-change enforcement
- GIVEN a change PR that adds a new node label `Beneficiary`
- WHEN reviewers inspect the change
- THEN `docs/acord-mapping.md` MUST contain a row mapping `Beneficiary`
       to its AIM source
- AND CI MUST fail the change if the row is missing.
