# Delta for API Contract (non-functional)

## MODIFIED Requirements

### Requirement: Latency budgets
The end-to-end p95 latency for `/v1/answer` SHALL be ≤ **1.5 s** under
nominal load (≤ 50 RPS sustained, ≤ 100 RPS burst), allocated as in
the bootstrap spec. The `latency_ms_breakdown` envelope in the answer
payload MUST report each stage. Per-stage numbers MAY be tuned by
later changes; the **stage breakdown contract** MUST be preserved.

#### Scenario: Burst handling
- GIVEN sustained load at 50 RPS and a 30-second burst to 100 RPS
- WHEN clients call `/v1/answer`
- THEN the p95 over the burst window MUST NOT exceed 2.5 s
- AND no request is rejected with a 5xx solely due to overload.

## ADDED Requirements

### Requirement: Availability, RPO, RTO
The serving layer SHALL meet the following monthly SLOs:

| Metric                | Target              |
|-----------------------|---------------------|
| Read availability     | ≥ 99.9 %            |
| Write availability    | ≥ 99.5 %            |
| RPO (data loss)       | ≤ 15 minutes        |
| RTO (recovery)        | ≤ 1 hour (primary region) |

The implementation MUST run continuous backups (WAL or equivalent)
and at least one hot-standby instance in the same region. A monthly
SLO report SHALL be published.

#### Scenario: SLO breach reported
- GIVEN the read endpoint had 50 minutes of unavailability in a month
- WHEN the SLO report is produced
- THEN the read availability is reported as below 99.9%
- AND a remediation entry is opened.

### Requirement: Capacity guardrails
The system SHALL be sized for at least 5 × 10⁷ nodes and 5 × 10⁸ edges
at v1. The serving layer MUST:

1. Emit an alert when any `RiskPeril` node has more than 5 × 10⁵
   incoming edges (super-node guard).
2. Honour each Cypher template's manifest `max_rows` and truncate +
   log when exceeded.
3. Refuse to run cross-currency aggregations without an explicit
   `convert_to` parameter.

#### Scenario: Super-node alert
- GIVEN peril `PER_FLU` accumulates 6 × 10⁵ incoming edges
- WHEN the daily metrics job runs
- THEN an alert is raised
- AND the relevant Cypher templates are flagged for review.

### Requirement: Index rebuild policy
When an index (vector or full-text) is being rebuilt:

1. Reads SHALL continue from the previous index version until the new
   version reports `ONLINE`.
2. Writes that depend on the new index SHALL be rejected with
   `503 index_rebuild_in_progress` and a `Retry-After` header.
3. `GET /v1/health` SHALL surface `status="degraded"` and list the
   affected index.

Full vector index rebuild MUST complete in ≤ 30 minutes at v1 scale;
full-text rebuild MUST complete in ≤ 15 minutes. Beyond these
budgets, an incident is declared automatically.

#### Scenario: Health surfaces rebuild
- GIVEN the vector index is `POPULATING`
- WHEN `GET /v1/health` is called
- THEN the response indicates `status=degraded`
- AND lists `clause_text_embeddings` as the affected index.
