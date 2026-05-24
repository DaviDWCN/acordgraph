# Design: Harden Ontology & Temporality

## 1. Decisions

### 1.1 `Endorsement` becomes a first-class node
- Label: `Endorsement`
- Properties: `id` (prefix `END_`), `effective_date: Date`,
  `recorded_at: DateTime`, `reason_code: String`, `actor: String`,
  `source_doc_id?`, `confidence?`.
- Edges (added to the closed catalogue):
  - `(:Endorsement)-[:SUPERSEDES]->(:Clause|:Coverage)` — points at the
    closed (`is_active=false`) edge endpoint by id.
  - `(:Endorsement)-[:INTRODUCES]->(:Clause|:Coverage)` — points at the
    new (`is_active=true`) edge endpoint by id.
  - `(:Endorsement)-[:AMENDS]->(:Policy)` — scope anchor.

> Rationale: relationship-pointing-at-relationship is not supported by
> Neo4j; we therefore have `Endorsement` reference the **clause** /
> **coverage** nodes, with both the closed and the new versions of the
> endorseable edge carrying a shared `endorsement_id` property as a
> cross-check. The pair (graph edges + edge property) gives O(1) audit
> drill-down and survives copy/restore.

### 1.2 Node-level temporality
Two patterns were considered:

| Option | Pros | Cons |
|---|---|---|
| A. Full reified `*_State` nodes (`(:Policy)-[:HAS_STATE]->(:PolicyState {valid_from, valid_to, status, …})`) | Clean as-of joins; auditable | Doubles node count, more complex writes |
| B. SCD-2 properties on the node itself, with prior states stored as `valid_to`-stamped `history: List<Map>` | Compact | Lists in Neo4j defeat indexing; brittle |

**Chosen: Option A** for `Policy`, `Party`, `RiskPeril`. The reified
state node is keyed `id = <parent_id>_v<n>` and carries the same
bitemporal triple as edges. The parent node retains a denormalised
"latest" projection of the same fields for fast point reads.

### 1.3 `Subject` subtypes
Adopt **multi-label** pattern (`:Subject:PersonSubject`,
`:Subject:VehicleSubject`, `:Subject:PropertySubject`). Common `id`,
`description`, `subject_type` remain on the `:Subject` super-label;
subtype-specific required fields land on the secondary label so range
indexes can be subtype-scoped without overloading.

- `PersonSubject`: `national_id_token` (PII vault token, see Change 4),
  `dob_year` (PII-safe granularity), `gender?`.
- `VehicleSubject`: `vin`, `plate_number?`, `make?`, `model?`,
  `manufacture_year?`.
- `PropertySubject`: `address_token`, `property_type`, `gps_geohash?`.

### 1.4 Generic peril coding
Replace `RiskPeril.icd_code` (sole, hard-coded) with:
- `code_system: String` ∈ {`ICD-10`, `ICD-11`, `ACORD-CauseOfLoss`,
  `ACORDGRAPH-INTERNAL`}.
- `code_value: String`.
- Read-through derived property `icd_code` (computed at query time
  via a Cypher view or via a virtual property in the API layer) — only
  populated when `code_system = 'ICD-10'`.

Index `(code_system, code_value)` composite range index for blocking
during entity resolution.

### 1.5 `BUYS` / `INSURES` enrichment
- `BUYS`: add `share_pct: Float [0,1]`,
  `relationship_to_insured: String`, alongside existing `role`.
- `INSURES`: add `sum_insured: Decimal`, `currency: String` (ISO 4217),
  `deductible: Decimal`.
- Both edges remain in the bitemporal-edge set.

### 1.6 Money & currency
Every monetary attribute (`Claim.amount_claimed`,
`INSURES.sum_insured`, `INSURES.deductible`,
`Coverage.payout_amount?`) MUST be paired with a `currency` ISO-4217
property at the same scope. The writer rejects payloads that violate
the pairing.

### 1.7 `Coverage` reification trigger
Reification is **required** when any of the following hold for a
`(InsuranceProduct)-[:CONTAINS]->(Clause)-[:COVERS]->(RiskPeril)`
chain:
1. An `Endorsement` modifies `payout_ratio` or
   `waiting_period_days` for a specific `Policy`.
2. A `Rider` (modelled as a sub-product attached via
   `[:RIDES_ON]->(InsuranceProduct)`) changes those numbers.
3. Two policies on the same product carry divergent runtime numbers
   for the same `(Clause, RiskPeril)` pair.

In all other cases the simple edge form is retained.

### 1.8 `is_active` becomes derived
The writer SHALL set `is_active = (valid_to IS NULL OR valid_to > now())`
in the same transaction as `valid_to`. A constraint test in CI ensures
no edge violates this invariant. Readers MAY use either form.

### 1.9 ACORD mapping document
New file `docs/acord-mapping.md` carries a row per AIM v2.x class with
columns:

| AIM Class | acordgraph projection | Coverage | Notes |
|---|---|---|---|

Every future change that touches `specs/ontology/spec.md` MUST update
this file in the same PR; CI lints this co-change.

## 2. Open Questions (parked)

1. Should `PolicyState` be modelled as a doubly-linked list
   (`[:PREVIOUS]`) for fast "previous version" reads, or rely on
   `valid_to` range queries?
2. Are `Rider`s a distinct label or a sub-label of `InsuranceProduct`
   with `is_rider=true`? Both work; defer until first commercial P&C
   product lands.
3. Where to keep ACORD code-list reference data (Cause-of-Loss,
   PartyRole)? In-graph (`:RefCode`) vs out-of-graph config — punted to
   Change 2 (`extend-ingestion-and-lineage`).
