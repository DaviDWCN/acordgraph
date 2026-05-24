# Architecture Optimizations vs. Inbound Brief v1.1

This document summarises the **industry-best-practice** upgrades applied
on top of the inbound technical brief. It is the human-friendly mirror
of section 2 in
`openspec/changes/bootstrap-acord-kg/design.md`.

## TL;DR

| Theme            | Inbound v1.1                              | This design                                                                    |
|------------------|-------------------------------------------|--------------------------------------------------------------------------------|
| Reasoning model  | Vector → Cypher → LLM                     | Vector + Lexical → RRF → Cross-encoder rerank → Cypher → Two-pass grounded LLM |
| Truth source     | Graph (implicit)                          | Graph (explicit, LLM-Cypher forbidden in prod)                                 |
| Versioning       | `is_active` flag                          | Bitemporal (`valid_from`, `valid_to`, `recorded_at`) + `Endorsement` event     |
| Provenance       | —                                         | `source_doc_id`, `source_page`, `extractor_version`, `confidence` everywhere   |
| Entity Resolution| Cosine > 0.89 + LLM                       | Blocking-key → cosine → LLM judge → HITL queue                                 |
| Citations        | "do not fabricate"                        | Validator rejects any cited `clause_id` not in retrieved sub-graph             |
| Eval             | —                                         | Golden set + Ragas + custom subgraph-overlap metric, gated in CI               |
| PII              | —                                         | Tokenised at ingest; vault-resolved at serving                                 |
| Cypher syntax    | `vector.similarity-function` (hyphen)     | `vector.similarity_function` (underscore — required by Neo4j 5.13+)            |
| Multi-lingual    | Implicit                                  | `lang` property; ICD-10 used as cross-lingual peril anchor                     |

## Why these matter

### 1. Cross-encoder reranking
Bi-encoder cosine alone collapses on near-synonyms common in medical
clauses ("心肌梗塞" / "心肌梗死" / "myocardial infarction"). A
cross-encoder evaluates query-document pairs jointly and improves
precision at top-5 dramatically — this is the single largest lift in
GraphRAG quality at low marginal cost.

### 2. Forbidding LLM-generated Cypher in production
LLM-written Cypher is a tempting demo but fails in audit reviews: a
malformed traversal can silently widen the set of returned clauses and
turn a "covered" answer into a regulatory liability. Templated,
parameterised Cypher is mandatory.

### 3. Bitemporality
Claims are evaluated against the policy state at **date of loss**, not
the current state. A simple `is_active` flag cannot answer "what did the
policy cover on 2024-09-12?". Bitemporal edges make as-of queries a
one-line filter.

### 4. Confidence-aware promotion
Extractor outputs vary in quality. Surfacing low-confidence clauses to
the retrieval layer pollutes recall metrics and erodes user trust. A
hard cutoff (`confidence < 0.6` blocked, 0.6–0.8 staged, ≥ 0.8 active)
matches what mature RAG products do.

### 5. Two-pass answerer with citation validation
The LLM emits a JSON of {answer_skeleton, citations[]}; a deterministic
renderer verifies that every cited id exists in the retrieved sub-graph
before producing the user-visible answer. This shifts hallucination
detection from human eyeballs to a unit-testable invariant.

### 6. HITL queue for the ambiguous band
Cosine 0.80–0.89 is a known false-positive zone for medical entities.
Routing those to a human-review queue protects against silent merging
of distinct conditions (e.g., "脑梗塞" vs "脑出血" — both stroke-like
embeddings but opposite clinical meaning).

### 7. Latency budget breakdown
Single SLO numbers ("p95 < 1.5s") are necessary but insufficient. Per
stage budgets make regressions diagnosable in production without
instrumenting from scratch during the incident.

## Updates from follow-up changes

> The four follow-up OpenSpec changes (`harden-ontology-and-temporality`,
> `extend-ingestion-and-lineage`, `expand-retrieval-and-api`,
> `governance-pii-and-sla`) further refine this design. Notable
> deltas vs the table above:
>
> - **Embedding dimension** is no longer hard-coded to 1536. It is
>   configurable per environment (1536 for OpenAI-class models, 1024
>   for BGE-M3, 768 for E5-Mistral); the contract is that the
>   ingestion pipeline and the vector index agree. See
>   `openspec/changes/harden-ontology-and-temporality/`.
> - **Provenance** is promoted from scattered properties to first-class
>   `:Document` and `:Chunk` nodes linked via `[:EXTRACTED_FROM]`.
>   See `openspec/changes/extend-ingestion-and-lineage/`.
> - **Cypher templates** are organised into a Catalogue
>   (`assets/cypher/catalog.yaml`); each query family has a stable
>   `intent_id`. See `openspec/changes/expand-retrieval-and-api/`.
> - **Exclusion-vs-coverage** precedence is now a four-layer rule
>   (Endorsement > Rider > base-Exclusion > base-Coverage), not a
>   single "exclusion wins" flag.
> - **PII** coverage extends to `Chunk.text`, embeddings, and source
>   filenames; embedding inversion is mitigated by embedding only the
>   redacted form. See `openspec/changes/governance-pii-and-sla/`.

## Risks deliberately accepted at this stage

- Vendor selection (LLM, embeddings, reranker) is **deferred**. The
  contract is written so any vendor satisfying the dimension/quality
  bar can be slotted in.
- `Coverage` reified node is offered as **optional** — only required
  when riders / endorsements override base product economics. Starting
  with the edge form keeps the v1 schema simple.
- HITL queue tooling is **out of scope** here; the requirement is
  captured so the next change can choose the implementation (e.g.,
  Argilla, custom Streamlit, Jira ticket).
