# Tasks — harden-ontology-and-temporality

> Documentation-only change. The implementation backlog below is the
> work picked up by the next `implement-*` change; checkboxes start
> unchecked.

## 1. Spec authoring (this change)

- [ ] 1.1 Author MODIFIED + ADDED requirements in
      `specs/ontology/spec.md`
- [ ] 1.2 Author MODIFIED requirement in `specs/retrieval/spec.md`
- [ ] 1.3 Publish `docs/acord-mapping.md`
- [ ] 1.4 Update top-level README index to point at this change

## 2. Implementation backlog (next change)

- [ ] 2.1 Add `Endorsement` to constraints + indexes file
- [ ] 2.2 Add `(code_system, code_value)` composite index on
      `RiskPeril`
- [ ] 2.3 Implement `PolicyState`, `PartyState`, `RiskPerilState`
      reified nodes with bitemporal triple
- [ ] 2.4 Migrate `RiskPeril.icd_code` → `(code_system, code_value)`
      with read-through alias
- [ ] 2.5 Extend writer validators for new `BUYS` / `INSURES`
      properties, currency pairing, derived `is_active`
- [ ] 2.6 Implement `Coverage` reification trigger logic
- [ ] 2.7 As-of resolver: graph traversal MUST use state nodes when
      attribute history is requested
- [ ] 2.8 Backfill / migration job for existing v1 graphs
