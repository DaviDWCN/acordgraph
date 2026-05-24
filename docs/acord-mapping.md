# ACORD ↔ acordgraph Mapping

> **Status:** authoritative source of truth for ACORD AIM v2.x
> coverage in this repository. Every OpenSpec change that adds,
> renames, or removes a label, edge, or major property MUST update
> this file in the same change.

## Conventions

- **Projection** describes how the AIM class manifests in the LPG:
  `Label`, `Label (multi-label)`, `Property on <Label>`, `Edge`,
  `State node`, or `Not modelled`.
- **Coverage** is one of:
  - `Full` — every required AIM attribute has a graph counterpart.
  - `Partial` — only the attributes called out in "Notes" are
    represented; others are intentionally deferred.
  - `None` — class is recognised by ACORD but not modelled here.

## Party pillar

| AIM Class            | Projection                                | Coverage | Notes |
|----------------------|-------------------------------------------|----------|-------|
| `Party`              | `:Party`                                  | Partial  | `name`, `type`, `acord_code`, `lang`; PII fields tokenised (see Change 4). |
| `Person`             | `:Party {type='Individual'}` + state node | Partial  | DOB stored only as `dob_year` on `PersonSubject` for PII reasons. |
| `Organization`       | `:Party {type='Organization'}`            | Partial  | LEI / tax IDs deferred. |
| `PartyRole`          | Edge property `role` on `[:BUYS]`         | Partial  | Roles: `PolicyHolder`, `Insured`, `Beneficiary` (others deferred). |
| `PartyContact`       | Not modelled                              | None     | Lives in PII vault, joined at serving. |
| `PartyRelationship`  | `:BUYS.relationship_to_insured`           | Partial  | Free-text today; will be promoted to a code list if it grows. |

## Agreement pillar

| AIM Class            | Projection                              | Coverage | Notes |
|----------------------|-----------------------------------------|----------|-------|
| `Agreement`          | `:Policy`                               | Partial  | Specialised to insurance policy form only. |
| `InsurancePolicy`    | `:Policy` + `:PolicyState`              | Full     | Bitemporal via state nodes + edge time triples. |
| `Product`            | `:InsuranceProduct`                     | Partial  | `line_of_business` ∈ {L&A, P&C}. |
| `Rider`              | `:InsuranceProduct` with `[:RIDES_ON]`  | Partial  | Modelled as sub-product, not a distinct label. |
| `Clause`             | `:Clause`                               | Full     | Bitemporal `[:CONTAINS]` edge + provenance. |
| `Coverage`           | `[:COVERS]` edge **or** `:Coverage` node| Full     | Reified per trigger (see ontology spec). |
| `Endorsement`        | `:Endorsement` + `SUPERSEDES/INTRODUCES`| Full     | Audit trail via dual edge + `endorsement_id` cross-property. |
| `AgreementParty`     | `[:BUYS]`                               | Full     | `role`, `share_pct`, `relationship_to_insured`. |
| `Premium`            | Not modelled                            | None     | Deferred to billing change. |

## Subject pillar

| AIM Class             | Projection                                  | Coverage | Notes |
|-----------------------|---------------------------------------------|----------|-------|
| `Subject`             | `:Subject` (super-label)                    | Partial  | Always paired with one subtype label. |
| `PersonSubject`       | `:Subject:PersonSubject`                    | Partial  | PII tokens, `dob_year` only. |
| `VehicleSubject`      | `:Subject:VehicleSubject`                   | Partial  | VIN, plate, make/model. |
| `PropertySubject`     | `:Subject:PropertySubject`                  | Partial  | Address token + geohash. |
| `RiskPeril`           | `:RiskPeril` + `:RiskPerilState`            | Full     | `code_system`/`code_value` (ICD-10/11, ACORD CauseOfLoss). |
| `SubjectRelationship` | Not modelled                                | None     | Deferred. |

## Claim pillar

| AIM Class            | Projection                              | Coverage | Notes |
|----------------------|-----------------------------------------|----------|-------|
| `Claim`              | `:Claim`                                | Partial  | `amount_claimed`+`currency`, `date_of_loss`, `report_date`, `incident_location`. |
| `ClaimParty`         | Not modelled                            | None     | Joined via `Policy → BUYS → Party`. |
| `ClaimItem`          | Not modelled                            | None     | Single-item claims only at v1. |
| `Loss`               | `:Claim` properties + `[:TRIGGERED_BY]` | Partial  | Loss subject via `[:ON_SUBJECT]`. |

## Reference & infrastructure (not in AIM)

| Concept              | Projection                              | Notes |
|----------------------|-----------------------------------------|-------|
| Document lineage     | (introduced in Change 2)                | `:Document`, `:Chunk` lineage nodes. |
| Quarantine queue     | Out of graph                            | Persisted in operational store. |
| HITL review queue    | Out of graph                            | Persisted in operational store. |

## Deliberate non-coverage (rationale)

- **Billing, commissions, reinsurance treaties** — out of scope at v1.
  Will be added when a downstream consumer asks; no schema impact is
  expected since they attach via edges to existing `Policy` / `Party`.
- **Free-form `PartyContact`** — PII risk too high to model in the
  knowledge graph; lives in the secure vault and is joined only at
  serving with row-level authorisation.
- **`ClaimItem` / `LossDetail` sub-records** — collapsed into `Claim`
  properties at v1; will be promoted to a sub-label when multi-item
  claims arrive.
