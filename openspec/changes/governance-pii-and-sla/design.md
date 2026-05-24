# Design: Governance, PII Hardening & Operational SLAs

## 1. PII surface — the full list

Beyond `Party.*`, the following can carry PII and must be governed:

| Carrier                | Risk                                      | Control                                                            |
|------------------------|-------------------------------------------|--------------------------------------------------------------------|
| Source PDF / DOCX      | Raw PII (national id, DOB, address)       | Stored only in secure document store; serving join with entitlements |
| `Chunk.text`           | Re-extraction risk                        | Redacted with the same tokeniser used for `Party`; raw kept in doc store |
| `Clause.embedding`     | Embedding-inversion attack                | Embedding produced from **redacted** text; re-embed on policy change |
| `Clause.text_content`  | Verbatim clause may quote PII             | Same redaction tokeniser; verbatim raw in doc store                |
| `Claim.amount_claimed` | Combined with party can identify a person | Row-level authorisation; never leaked via 404→403 path             |
| `Subject.*` (Person)   | DOB, national id                          | `national_id_token`, `dob_year` only (no full DOB)                 |
| Document filename      | May contain `Zhang_San_health.pdf`        | Filename is itself tokenised; raw filename in doc store            |

### 1.1 Embedding-inversion defence
Embedding inversion (Song & Raghunathan, 2020; recent CRAFT-style
attacks) can reconstruct meaningful fragments of training text from
the embedding vector. The contract:

- The text fed to the embedding model MUST be the **redacted** form
  used for `Chunk.text`.
- Re-embedding of every affected `Clause` MUST be triggered when the
  redaction policy changes (new entity types, new tokeniser
  version); the trigger is recorded as an OpenSpec change.
- Vector indexes MUST NOT be exposed to callers without row-level
  entitlement.

## 2. Currency & FX policy

- Every monetary value (`Claim.amount_claimed`, `INSURES.sum_insured`,
  `INSURES.deductible`, `Coverage.payout_amount?`) is stored with its
  native ISO 4217 `currency` code.
- Retrieval and serving MUST NOT silently convert across currencies.
- A separate request flag `convert_to: <ISO>` on `/v1/answer` may
  trigger conversion. When set, the response MUST include:
  - `fx_source` (provider identifier),
  - `fx_rate`,
  - `fx_as_of: DateTime`,
  - a structured `disclaimer` indicating the answer involved
    conversion.
- Cross-currency aggregations (rollups) MUST refuse to run without an
  explicit `convert_to`.

## 3. Operational SLOs

| Concern                | Target                                                    | Rationale                              |
|------------------------|-----------------------------------------------------------|----------------------------------------|
| Availability (read)    | 99.9% monthly (≈ 43m downtime / month)                    | Customer-facing answer endpoint.       |
| Availability (write)   | 99.5% monthly                                             | Tolerates ingestion maintenance.       |
| RPO                    | ≤ 15 minutes                                              | Continuous backups + WAL shipping.     |
| RTO                    | ≤ 1 hour for primary-region recovery                      | Hot-standby in same region.            |
| RPS ceiling (`/answer`)| 50 sustained / 100 burst                                  | Matches latency budget basis.          |
| Graph size ceiling     | 5 × 10⁷ nodes; 5 × 10⁸ edges at v1                        | Below super-node-fanout cliffs.        |
| Vector index rebuild   | ≤ 30 minutes for full rebuild at v1 scale                 | Read traffic remains served from old index until rebuild succeeds. |
| Full-text rebuild      | ≤ 15 minutes at v1 scale                                  | Same dual-index pattern.               |

### 3.1 Capacity guardrails
- A super-node guard: any `RiskPeril` reaching > 5 × 10⁵ incoming
  edges MUST trigger an alert; the resolver MAY shard such perils by
  `line_of_business`.
- Cypher templates with potential fan-out (`OPTIONAL MATCH` over
  unindexed properties) MUST carry a `max_rows` parameter in their
  manifest; the runner truncates and logs when exceeded.

### 3.2 Index dual-write during rebuild
When an index is being rebuilt, the catalogue runner MUST switch
reads to the previous index version and reject writes that would
require the new index, until the new index reports `ONLINE`. The
`/v1/health` endpoint MUST surface this state as `degraded`.

## 4. Documentation fixes

- `docs/architecture-optimizations.md` row 4: replace the assertion
  that "1536 is portable across OpenAI / Cohere / BGE-M3" with a
  pointer to Change 1's configurable-dimension model. The new row
  reads: *"Embedding dimension is configurable per environment; 1536
  is the default for OpenAI-class models, 1024 for BGE-M3, 768 for
  E5-Mistral. The contract is that ingestion and the index agree."*
- README is extended with links to the four follow-up changes and to
  `docs/glossary.md`.

## 5. Open Questions (parked)

1. PII tokeniser choice (deterministic encryption vs HMAC) remains
   the same parked decision as in `bootstrap-acord-kg` design §4.
2. FX provider, refresh cadence, and historical rate retention are
   not bound here.
3. Multi-region active-active vs active-passive deployment shape is
   left to the implementation change that chooses the cloud target.
