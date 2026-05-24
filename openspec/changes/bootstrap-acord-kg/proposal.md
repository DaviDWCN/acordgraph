# Proposal: Bootstrap ACORD-aligned Insurance Knowledge Graph

## Intent
Establish the foundational **requirements** and **architecture** for an
insurance knowledge graph built on the ACORD Information Model and served
through a GraphRAG hybrid retrieval API. The first change in this
greenfield repository captures the *source-of-truth* specs so that all
subsequent implementation changes have a stable contract to delta against.

## Why now
- The business needs deterministic, citation-able answers to multi-hop
  policy / coverage / claim questions; pure vector RAG cannot guarantee
  this.
- Aligning early with **ACORD AIM v2.x** prevents semantic drift between
  core systems, CRM, claims and the LLM layer.
- Locking the **Labeled Property Graph (LPG)** shape in Neo4j unblocks
  parallel work on (a) structured ETL from core, (b) LLM clause
  extraction, and (c) retrieval API engineering.

## Scope
This change adds, as new requirements (no MODIFIED / REMOVED — the
repository is empty):

- **Ontology** — node labels, properties, relationships, identifier and
  cardinality rules, bitemporal endorsement model, multilingual support.
- **Ingestion** — dual-track ingestion (structured ETL + LLM extraction
  from unstructured PDFs); extraction prompt contract; JSON Schema
  validation; provenance & confidence capture.
- **Retrieval** — hybrid GraphRAG flow (vector pre-filter → Cypher
  sub-graph extraction → context assembly → grounded answer); reranking;
  must-cite policy.
- **Governance** — entity resolution thresholds, PII handling, audit
  trail, versioning / endorsements, evaluation harness expectations.
- **API** — public contract surface (resolve, query, explain) without
  binding to a specific framework.

## Approach
1. Adopt OpenSpec layout under `openspec/`.
2. Persist the inbound technical brief (v1.1) under `docs/` as the
   canonical reference and complement it with
   `docs/architecture-optimizations.md` documenting deviations and
   industry-best-practice upgrades agreed in `design.md`.
3. Ship reference assets (Cypher DDL, extraction prompt, JSON Schema,
   GraphRAG Cypher) under `assets/` so the next change ("implement-*")
   can lift them unmodified.
4. Defer all runtime code, vendor selection and SLA numbers.

## Non-goals
- No application code, package manifests, CI pipelines or deployment
  manifests are introduced in this change.
- No commitment to a specific LLM, embedding model, reranker, or
  orchestration framework (LangChain / LlamaIndex / DSPy). The design
  identifies the integration seams only.

## Acceptance Summary
- All five domain delta specs exist with at least one Scenario per
  Requirement.
- `design.md` enumerates architecture decisions and the optimizations
  applied on top of the inbound brief.
- `tasks.md` lists the implementation backlog (unchecked) for the next
  change.
- `assets/` contains validated Cypher / JSON-Schema / prompt files
  referenced by the specs.
