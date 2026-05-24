# Proposal: Governance, PII Hardening & Operational SLAs

## Intent
Round out the non-functional contract: harden PII handling beyond
`Party`, define availability / RPO / RTO / capacity targets, and
fix a handful of documentation inconsistencies so the four-change
arc lands self-consistently.

## Why now
- PII tokenisation currently covers `Party` only. Source PDFs, claim
  forms, `Chunk.text`, and clause embeddings can also leak PII —
  notably via **embedding-inversion** attacks against the vector
  index.
- Availability, RPO, RTO, RPS ceiling, and graph-size ceiling are
  unspecified. Without them the implementation team cannot size the
  Neo4j cluster, choose backup cadence, or set rate limits.
- Money types are now scoped (Change 1) but the **currency conversion
  policy** at serving time is unwritten — leading to ambiguous
  multi-currency rollups.
- `docs/architecture-optimizations.md` row 4 reasons that "1536 is
  portable across OpenAI/Cohere/BGE-M3", which is factually wrong for
  BGE-M3 (default 1024). Needs correction in light of Change 1's
  embedding-dimension liberalisation.
- The repository has no central **glossary**, so terminology drifts
  between specs (AIM, LPG, RRF, HITL, bi-temporal, reified, …).

## Scope (ADDED / MODIFIED — no REMOVED)

### MODIFIED — `governance`
1. Extend PII tokenisation to **all carriers**: source PDFs and
   `Chunk.text` must be redacted at ingest; raw text resides only in
   the secure document store with row-level entitlements at serving.
2. Add an **embedding-inversion defence**: any embedding vector
   indexed in the graph MUST be derived from PII-redacted text only.
   Re-embedding is required whenever the redaction policy changes.

### ADDED — `governance`
3. Define a **currency policy**: store values + ISO-4217 code; never
   silently convert at serving. A separate `currency_conversion`
   sub-call (with an explicit FX source and timestamp) is required
   for cross-currency rollups, and the result MUST carry an
   audit-visible disclaimer.

### MODIFIED — `api`
4. Promote latency budgets to a fuller **non-functional contract**:
   availability, RPO, RTO, RPS ceiling, graph-size ceiling, and
   index-rebuild policy.

### ADDED — repository documentation
5. Ship `docs/glossary.md` covering every term used across specs.
6. Fix `docs/architecture-optimizations.md` row 4 (embedding-dimension
   rationale) and add a forward-pointer to Change 1's
   configurable-dimension model.

## Approach
Documentation-only. New file is `docs/glossary.md`. Updates to
`docs/architecture-optimizations.md` are narrow (one row + one
paragraph).

## Non-goals
- No PII vault implementation decision (deterministic encryption vs
  HMAC) — flagged in the original `bootstrap-acord-kg` design and
  remains parked.
- No specific FX rate provider — only the contract for storing /
  citing the rate is fixed.
- No capacity sizing for specific cloud vendors.

## Acceptance Summary
- `specs/governance/spec.md` (this delta) extends PII coverage and
  introduces the currency policy.
- `specs/api/spec.md` (this delta) adds availability / RPO / RTO /
  capacity requirements.
- `docs/glossary.md` exists and is referenced from README.
- `docs/architecture-optimizations.md` row 4 reads correctly.
