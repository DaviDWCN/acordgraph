# Proposal: Harden Ontology & Temporality

## Intent
Close the structural gaps in the v1 ontology delivered by
`bootstrap-acord-kg` so that downstream implementation changes have a
self-consistent, ACORD-traceable, fully bitemporal schema to build on.

## Why now
The bootstrap change ships a usable v1 ontology but, on review, has
several internal inconsistencies and missing semantics that — if left
in place — will force a v2 schema migration shortly after go-live:

- `Endorsement` is referenced by indexes, design and governance specs
  but is **not** part of the ontology's node catalogue or relationship
  catalogue (which is a closed set). Endorsement-bound audit trails
  cannot be written.
- Bitemporality is only specified on edges. Node attributes that
  legitimately change over time (`Policy.status`, `Party.name`,
  `RiskPeril.aliases`) have no "as-of" answer.
- `Subject` cannot describe a P&C risk object (vehicle VIN, property
  address, sum insured). Claims cannot point at *which* subject the
  loss happened on.
- `RiskPeril.icd_code` is the only code-system property, blocking P&C
  perils that have no ICD.
- `BUYS` / `INSURES` lack the properties needed to distinguish
  policyholder vs insured vs beneficiary and to carry sums insured.
- The `Coverage` reified-node escalation rule lives in `design.md` but
  is never a requirement, so implementers have no objective trigger.
- There is no published ACORD-class ↔ acordgraph-label mapping table,
  so the "ACORD-aligned" claim cannot be audited.
- Money has no `currency`; `recorded_at` and `is_active` co-exist
  without a derivation rule.

## Scope (ADDED / MODIFIED — no REMOVED)

### MODIFIED — `ontology`
1. Add `Endorsement` to the node catalogue with required properties and
   the relationships that attach it to superseded / superseding edges.
2. Extend the closed relationship catalogue with the endorsement-event
   edges and with new properties on `BUYS` and `INSURES`.
3. Promote node-level temporality: every mutable property on `Policy`,
   `Party`, `RiskPeril` MUST be retrievable as-of any historical date,
   either via reified `*_State` nodes or `[:HAS_STATE]` time-slice
   edges (one mechanism, chosen here).
4. Replace `RiskPeril.icd_code` with the generic pair
   `code_system / code_value` (back-compat: `icd_code` remains as a
   derived read-through alias).
5. Refine `Subject` into subtype labels `PersonSubject`, `VehicleSubject`,
   `PropertySubject` with type-specific required fields.
6. Tie `Claim` to a `Subject` via `[:ON_SUBJECT]` and add
   `currency`, `report_date`, `incident_location`.
7. Make `Coverage` reification a hard requirement when (and only when)
   an `Endorsement` overrides a base edge's
   `payout_ratio` / `waiting_period_days` for a specific `Policy`.
8. Define a derivation rule: `is_active = (valid_to IS NULL OR
   valid_to > now())`; writers MUST NOT set `is_active` independently.

### ADDED — `ontology`
9. New requirement: **ACORD class mapping table** (`docs/acord-mapping.md`)
   is the source of truth for AIM v2.x ↔ graph label/property/edge
   coverage and explicit non-coverage. Any new label/edge MUST update
   this table in the same change.

### MODIFIED — `retrieval`
10. The GraphRAG sub-graph lookup MUST consult the node-state mechanism
    when `as_of` is supplied (not just edge `valid_*`).

## Approach
Documentation-only change: update `specs/ontology/spec.md`,
`specs/retrieval/spec.md` (small delta), and ship a new
`docs/acord-mapping.md`. No asset (`assets/cypher/*`) is mutated here;
asset updates land in the implementation change that actually applies
the migration.

## Non-goals
- No data migration plan (deferred to `implement-*`).
- No vendor choice for endorsement event store.
- No change to embedding dimension or vector index (separate concern).

## Acceptance Summary
- `specs/ontology/spec.md` carries `MODIFIED` / `ADDED` blocks for all
  ten points above, each with a Scenario.
- `docs/acord-mapping.md` enumerates Party, Agreement, Subject, Claim,
  Endorsement and the AIM classes they project / drop.
- The relationship catalogue is updated such that the existing
  `assets/cypher/01_constraints_indexes.cypher` `Endorsement.id`
  constraint no longer dangles.
