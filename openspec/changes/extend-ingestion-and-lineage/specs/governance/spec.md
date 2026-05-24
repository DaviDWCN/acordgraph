# Delta for Governance & QA (lineage + staged confidence)

## MODIFIED Requirements

### Requirement: Lineage
For any node or edge returned at serving time, the system MUST be
able to surface the originating source document and page through a
**bounded graph traversal**, not a property lookup. The contract is:

- For nodes extracted from unstructured documents: at most two index-
  backed hops via `[:EXTRACTED_FROM]` and `[:HAS_CHUNK]` reach a
  `Document` node carrying `filename`, `sha256`, and `ingested_at`.
- For nodes ingested via structured ETL: a single hop along
  `[:SOURCED_FROM]` (or, in the v1 transitional period, the
  denormalised properties `source_system` / `source_record_id`) reaches
  the source-of-record identifier.

#### Scenario: Drill-down from an answer
- GIVEN an answer citing Clause `CL_502`
- WHEN an operator follows the lineage link
- THEN the traversal
       `(CL_502)-[:EXTRACTED_FROM]->(:Chunk)<-[:HAS_CHUNK]-(:Document)`
       returns a `Document` node within two hops
- AND its `filename`, `sha256`, and `source_page` (via the `Chunk`)
       are returned.

### Requirement: Confidence-aware promotion
Extracted nodes/edges with `confidence < 0.60` MUST NOT enter the
graph; they are written to the quarantine store. Those with
`0.60 ≤ confidence < 0.80` MUST be written with the secondary label
`:Staged` and a `staged_until: DateTime` property; they MUST NOT
appear in retrieval candidate lists. Promotion to active (clearing
`:Staged`) is the responsibility of a domain reviewer and MUST occur
before `staged_until`, otherwise the node is auto-quarantined.

#### Scenario: Staged clause is invisible to retrieval
- GIVEN a `Clause` stored with `confidence=0.72` and `:Staged`
- WHEN the retriever performs hybrid recall
- THEN this clause MUST NOT appear in the candidate list.

#### Scenario: Staged TTL expiry
- GIVEN a staged clause whose `staged_until` is yesterday
- WHEN the TTL sweeper runs
- THEN the clause is removed from the graph
- AND a quarantine entry with reason `staged_expired` is created
- AND the originating `Chunk` is preserved (lineage is not deleted).

## ADDED Requirements

### Requirement: Staged-band ownership and SLA
Every `:Staged` node SHALL carry `staged_owner: String` (review
queue id or reviewer principal) and `staged_reason: String` (the
trigger that placed it in the band). The governance dashboard MUST
expose the count of staged nodes per owner and the median age in the
band. The default staged TTL is 30 days; values longer than 60 days
MUST be approved via a tracked exception process and recorded as a
property `staged_ttl_override_reason`.

#### Scenario: SLA breach is observable
- GIVEN ten staged clauses are older than 25 days
- WHEN the governance dashboard refreshes
- THEN the affected owner queues are flagged "approaching SLA"
- AND an alert is emitted at 28 days.
