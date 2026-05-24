# Tasks — governance-pii-and-sla

## 1. Spec authoring (this change)

- [ ] 1.1 Author MODIFIED + ADDED requirements in
      `specs/governance/spec.md` (PII scope, embedding inversion,
      currency policy)
- [ ] 1.2 Author MODIFIED + ADDED requirements in
      `specs/api/spec.md` (availability, RPO/RTO, capacity, FX flag)
- [ ] 1.3 Ship `docs/glossary.md`
- [ ] 1.4 Patch `docs/architecture-optimizations.md` row 4 +
      forward-pointer
- [ ] 1.5 Add changes index + glossary link to README

## 2. Implementation backlog (next change)

- [ ] 2.1 Implement chunk-text and filename redaction pipelines
- [ ] 2.2 Make embedding generation consume redacted text only
- [ ] 2.3 Wire `convert_to` flag, FX provider adapter, and disclaimer
      block on `/v1/answer`
- [ ] 2.4 Add availability / RPO / RTO monitors and alerts
- [ ] 2.5 Add super-node guard for `RiskPeril`
- [ ] 2.6 Implement index dual-write / read-switch during rebuild
