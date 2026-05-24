# Design: Bootstrap ACORD-aligned Insurance Knowledge Graph

This document records the **architecture decisions** and the **best-practice
optimizations** applied on top of the inbound technical brief
(`docs/technical-spec.md`, v1.1). Each section calls out the original
proposal, the upgrade, and the rationale so reviewers can audit deltas
quickly.

## 1. Architectural Stance

### 1.1 Hybrid GraphRAG, graph-first

Vector search is treated as a **candidate generator** for `Clause`
nodes; the **graph** is the authoritative reasoner. The final answer is
*always* assembled from a deterministic Cypher traversal so that:

- Coverage / exclusion decisions are reproducible and citeable.
- The LLM operates as a renderer of facts, not a reasoner over ambiguous
  prose (mitigates hallucination on payout ratios, waiting periods,
  exclusions).

### 1.2 Three logical layers

```
        ┌──────────────────────────────────────────────┐
        │ L3 — Serving:    Resolver · Hybrid Retriever │
        │                  · Reranker · Answerer       │
        ├──────────────────────────────────────────────┤
        │ L2 — Knowledge:  Neo4j LPG (nodes/edges) +   │
        │                  native Vector Index +       │
        │                  Full-text Index             │
        ├──────────────────────────────────────────────┤
        │ L1 — Ingestion:  ETL (structured) · LLM      │
        │                  Extractor (unstructured) ·  │
        │                  Entity Resolver · Validator │
        └──────────────────────────────────────────────┘
```

L1 produces idempotent `MERGE` upserts keyed on stable `id`s. L2 enforces
schema and indexing. L3 owns latency budgets and grounding rules.

## 2. Optimizations over the v1.1 Brief

| # | Topic                                  | Brief (v1.1)                              | Upgrade in this design                                                                                                                                 | Rationale                                                                                              |
|---|----------------------------------------|-------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| 1 | Vector index option key                | `` `vector.similarity-function` ``        | `` `vector.similarity_function` `` (underscore)                                                                                                        | Matches Neo4j 5.13+ syntax; hyphen form is rejected by the planner.                                    |
| 2 | Coverage modelled only on edges        | `(Clause)-[:COVERS]->(RiskPeril)`         | Optional first-class `Coverage` node when payout structures vary by **Policy** (endorsements, riders), keeping the simple edge form for the base case. | Endorsements / riders frequently override `payout_ratio`, `waiting_period_days` per **policy**, not per product. A reified node admits per-policy overrides without exploding edge cardinality. |
| 3 | Bitemporality                          | `is_active` flag on `[:CONTAINS]`         | Bitemporal triple `valid_from`, `valid_to`, `recorded_at` on every endorseable edge; archived edges retained, never deleted.                          | Enables "as-of" queries needed by claims & audit; aligns with ACORD's temporal model.                  |
| 4 | Provenance                             | Not addressed                             | Every extracted node/edge carries `source_doc_id`, `source_page`, `extractor_version`, `confidence ∈ [0,1]`.                                          | Required for SOC2 audit, regulator drill-down, and confidence-weighted reranking.                      |
| 5 | Entity Resolution                      | Cosine > 0.89 + LLM judge                 | Two-stage: blocking on `icd_code` / `acord_code` / normalised name → cosine ≥ 0.89 → LLM judge → human-in-the-loop queue for 0.80–0.89 band.          | Reduces LLM cost; preserves human review where automated confidence is low.                            |
| 6 | Multi-lingual                          | Implicit                                  | `lang` property on `Clause` and `RiskPeril.aliases[]`; embeddings produced by a multilingual model; ICD-10 codes act as cross-lingual anchors.        | Insurance products are sold across markets; aliases prevent duplicate `RiskPeril` per locale.          |
| 7 | Retrieval pipeline                     | Vector → Cypher → LLM                     | Vector (top-k=20) → **cross-encoder rerank** (top-n=5) → Cypher sub-graph → context shrink → grounded answer with citations.                          | Cross-encoder cuts false positives that pure cosine cannot separate (e.g., "心肌梗塞" vs "心包炎"). |
| 8 | Indexes                                | Range + Vector                            | Adds **Full-text** index on `Clause.title`, `Clause.text_content` and `RiskPeril.name + aliases` for keyword fallback and BM25 fusion (RRF).          | Hybrid lexical-semantic fusion materially improves recall on rare named perils.                        |
| 9 | Identifiers                            | Single `id` field                         | Distinguishes **internal `id`** (opaque, hash-of-source) from **business keys** (`policy_number`, `claim_number`, `icd_code`) — both indexed.        | Prevents accidental coupling of graph identity to mutable business data.                               |
|10 | Grounding contract                     | "Must not fabricate"                      | **Two-pass answerer**: (a) JSON of cited facts produced by LLM, (b) renderer validates every cited `clause_id` exists in retrieved sub-graph; reject otherwise. | Hard guardrail against hallucinated clauses; deterministic citation rendering.                         |
|11 | Evaluation                             | Not addressed                             | A versioned **golden set** of Q→expected-subgraph pairs lives under `assets/eval/` (deferred to next change); CI gate on recall@k, faithfulness, citation-precision. | Required to detect drift when prompts, embeddings or ontologies change.                                |
|12 | PII / Security                         | Not addressed                             | `Party` PII fields tokenized at ingestion; raw values held in a separate encrypted store, joined only at serving with row-level authorization.        | GDPR / data-residency compliance; minimises blast radius of graph backups.                             |
|13 | Endorsement semantics                  | Soft via `is_active`                      | Endorsement modelled as an `Endorsement` event node referenced by archived and superseding edges; provides explainability and roll-back.              | Aligns with ACORD `Agreement` change events; supports "what changed on date D" queries.                |
|14 | Scale guardrails                       | Not addressed                             | Documented anti-patterns (super-nodes on common `RiskPeril`, runaway `OPTIONAL MATCH` fan-out); recommended sharding strategy by `line_of_business` partition labels. | Prevents perf cliffs at >10⁷ nodes; Neo4j operators have known cures listed.                          |

## 3. Component Decisions

| Concern               | Decision                                                                                          | Note                                              |
|-----------------------|---------------------------------------------------------------------------------------------------|---------------------------------------------------|
| Graph DB              | Neo4j 5.13+ (Community or Aura)                                                                   | Required for vector index GA + bitemporal indexes |
| Embedding             | Provider-agnostic; dimension fixed at **1536** for portability across OpenAI / Cohere / BGE-M3   | Selected per environment by config                |
| LLM extraction        | JSON-Schema-constrained decoding; temperature=0; max one retry on validation failure              | Determinism for ingest                            |
| Orchestration         | Plain Python service first; pluggable adapter so LangChain / LlamaIndex can be slotted in         | Avoid framework lock-in pre-PMF                   |
| Eval harness          | Pytest + Ragas (faithfulness, answer-correctness) + custom subgraph-overlap metric                | Implementation deferred                           |
| Observability         | OpenTelemetry traces for `resolve → retrieve → rerank → cypher → answer`                          | Latency budget per stage in `specs/api/spec.md`   |

## 4. Open Questions (parked, not blocking)

1. Reranker model selection (BGE-Reranker-v2 vs Cohere Rerank 3)?
2. Should `Party` PII tokenisation use deterministic encryption (joinable)
   or HMAC pseudonyms (non-joinable)?
3. Endorsement event sourcing: do we keep an `EndorsementLog` graph or
   delegate to an outside event store (Kafka topic) and only project
   active state into the graph?

These will be resolved in follow-up OpenSpec changes; the requirements
in this change are written so that any decision satisfies the contract.
