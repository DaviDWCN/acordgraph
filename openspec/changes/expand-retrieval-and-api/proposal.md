# Proposal: Expand Retrieval & API Surface

## Intent
Make the retrieval contract usable for the **full** range of business
questions the knowledge graph must answer, and round out the API
surface so the contract is implementable without further guessing.

## Why now
The bootstrap change ships exactly one Cypher template
(`assets/cypher/10_graphrag_lookup.cypher`) for coverage-judgment
queries, while forbidding runtime LLM-generated Cypher. That works for
the demo question class ("is peril X covered?") but cannot answer:

- Open claim listings, claim status timelines.
- Endorsement change history for a policy.
- All exclusions for a product (catalog questions).
- "Which clauses changed between 2024-Q1 and 2024-Q4?" (audit).
- Premium / sum-insured rollups.

Without a **template catalogue** and a published intent→template
mapping, implementers will either (a) silently re-enable LLM Cypher
or (b) ship a one-off pile of unmaintained queries. We also lack
write endpoints (`/v1/ingest`, `/v1/feedback`), a real lineage
endpoint, and precise metric definitions for the CI quality gate.
Finally, the "Exclusion takes precedence over Coverage" rule is too
blunt: it produces audit-failing wrong answers when a rider or
endorsement re-introduces coverage.

## Scope (ADDED / MODIFIED — no REMOVED)

### MODIFIED — `retrieval`
1. Introduce a **Cypher Template Catalogue** (`assets/cypher/`
   directory, indexed by an `intent_id`) as the only sanctioned source
   of executable queries. Each template MUST declare its parameter
   contract, its intent id, and a golden test case.
2. Refine "exclusion takes precedence" into a layered precedence:
   **endorsement-introduced coverage > rider coverage > base
   exclusion > base coverage**, ordered by `recorded_at` within the
   same layer. The answerer MUST surface every conflicting clause and
   the resolution layer chosen.

### MODIFIED — `api`
3. Add `POST /v1/ingest` (idempotent write) and `POST /v1/feedback`
   (user/HITL corrections fed back into the evaluation set) and
   `GET /v1/lineage/{node_id}` (drill-down endpoint).
4. Tighten the answer payload contract: include `intent_id`,
   `template_id`, `as_of`, `confidence_floor` so observability can
   bucket answers by query family.

### MODIFIED — `governance`
5. Replace the qualitative metric thresholds with formal definitions
   for `recall@5`, `citation_precision`, `faithfulness`, and a new
   custom `subgraph_overlap_f1`. Baseline freezing, regeneration, and
   roll-forward rules are specified here.

## Approach
Documentation-only. The catalogue is described as a spec contract
(directory layout, naming, manifest format); the actual `.cypher`
files in the catalogue are added by the implementation change.

## Non-goals
- No commitment to query planners or framework-level Cypher builders.
- No new vector index changes (still 1 vector + 1 full-text index per
  language).
- No public auth scheme decision — covered in Change 4.

## Acceptance Summary
- `specs/retrieval/spec.md` (this delta) adds the Catalogue
  requirement and reworks the precedence rule.
- `specs/api/spec.md` (this delta) lists the three new endpoints and
  the extended response shape.
- `specs/governance/spec.md` (this delta) carries formal metric
  definitions and a baseline-freezing requirement.
