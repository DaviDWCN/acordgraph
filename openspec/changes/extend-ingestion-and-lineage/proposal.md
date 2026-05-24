# Proposal: Extend Ingestion & Lineage

## Intent
Reconcile the ingestion regime with the reality of the source corpus
(claims, endorsements, multilingual wordings) and promote provenance
from "scattered properties" to **first-class lineage nodes** so that
audit, drill-down and prompt-injection defences become trivial graph
operations.

## Why now
The bootstrap change ships an extractor whose JSON Schema only
recognises `InsuranceProduct / Clause / RiskPeril`, yet the ingestion
spec advertises claim-form and endorsement extraction. That gap will
either be closed silently by extractor authors (drifting from the
contract) or surface as runtime quarantine storms. Provenance as a
scalar property is also a regulatory weak point: the governance spec
asks for "O(1) drill-down" but a property lookup is **not** a graph
hop. Finally, the extractor prompt is currently vulnerable to clause
text that contains injection payloads, and the Chinese full-text
recall is silently broken because the default Lucene analyzer does not
tokenise CJK.

## Scope (ADDED / MODIFIED — no REMOVED)

### MODIFIED — `ingestion`
1. Broaden the LLM extractor's permitted node set to
   `InsuranceProduct, Clause, RiskPeril, Claim, Endorsement, Party`
   and edge set to `{CONTAINS, COVERS, EXCLUDES, FILED_UNDER,
   TRIGGERED_BY, BUYS, AMENDS}`, scoped per source-document type
   (wording / claim-form / endorsement). Out-of-scope labels MUST be
   rejected at schema validation.
2. Require **prompt-injection isolation**: chunk text MUST be wrapped
   in a typed `<UNTRUSTED_INPUT>` block; the system prompt MUST refuse
   to honour instructions inside that block; numeric extractions
   (`payout_ratio`, `waiting_period_days`) MUST be re-verified against
   the original chunk via deterministic regex before write.
3. Mandate **CJK analyzer** on the `clause_fulltext` and
   `peril_fulltext` indexes when the deployed corpus contains any
   `lang ∈ {zh, ja, ko}` clauses. The default Lucene analyzer is
   forbidden in this case.
4. Define the **confidence band semantics** in full (`<0.6` blocked,
   `0.6–0.8` staged via a secondary `:Staged` label with a TTL and a
   review SLA, `≥0.8` active).
5. Replace the ad-hoc `PER_I21_9_ami`-style id construction with a
   deterministic recipe: `<PREFIX>_<base32(sha1(canonical_form))>`,
   with the business key (e.g., ICD code) carried in properties only.

### ADDED — `ingestion`
6. Introduce **`Document` and `Chunk` lineage nodes** owned by the
   ingestion pipeline; every extracted node/edge MUST link to the
   `Chunk` that produced it via `[:EXTRACTED_FROM]`. Document-level
   metadata (filename, mime type, ingest timestamp, content hash) moves
   off scattered properties onto the `Document` node.

### ADDED — `ontology`
7. Add `Document` and `Chunk` labels + the
   `[:HAS_CHUNK]`, `[:EXTRACTED_FROM]` edges to the closed catalogue.

### MODIFIED — `governance`
8. Restate the "Lineage" requirement so that drill-down is a 1-2 hop
   graph traversal (`Clause → Chunk → Document`), not a property
   lookup.
9. Define the staged-confidence governance contract (TTL, owner,
   escalation) introduced in (4).

## Approach
Documentation-only. Reference assets (`extractor_system.md`,
`extraction.schema.json`, `01_constraints_indexes.cypher`) are
**not** mutated here; their next revisions will land in the
implementation change that follows. The new spec text simply makes
the contract explicit.

## Non-goals
- No change to retrieval ordering (covered in Change 3).
- No selection of CJK analyzer vendor (`cjk`, `smartcn`, IK) — the
  contract demands "a CJK analyzer", not a specific one.
- No HITL UI choice (deferred).

## Acceptance Summary
- `specs/ingestion/spec.md` carries the five MODIFIED + one ADDED
  requirements above, each with at least one Scenario.
- `specs/ontology/spec.md` (this change's delta) adds `Document` /
  `Chunk` labels and the two new edges.
- `specs/governance/spec.md` restates Lineage as a graph traversal
  and adds the staged-confidence contract.
