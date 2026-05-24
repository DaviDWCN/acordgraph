# Tasks — bootstrap-acord-kg

> This change ships **specifications and reference assets only**; the
> tasks below are the implementation backlog handed to the next change.
> All checkboxes start unchecked on purpose.

## 1. Knowledge layer

- [ ] 1.1 Provision Neo4j 5.13+ instance (dev / staging / prod)
- [ ] 1.2 Apply `assets/cypher/01_constraints_indexes.cypher`
- [ ] 1.3 Validate vector index dimensions match the chosen embedding model
- [ ] 1.4 Seed reference data (ACORD codes, ICD-10 lookups, line-of-business)

## 2. Ingestion — structured

- [ ] 2.1 Build CDC / batch ETL from core / CRM sources
- [ ] 2.2 Implement idempotent `MERGE` writers per node label
- [ ] 2.3 Emit OpenTelemetry spans per batch with row counts and errors
- [ ] 2.4 Reconciliation report (graph row counts vs source-of-record)

## 3. Ingestion — unstructured (LLM)

- [ ] 3.1 PDF chunker (heading-aware, ≤ 1.5k token windows, 10% overlap)
- [ ] 3.2 Extractor wired with `assets/prompts/extractor_system.md` and
      `assets/schemas/extraction.schema.json` (JSON-Schema-constrained decode)
- [ ] 3.3 Provenance enrichment (`source_doc_id`, `source_page`,
      `extractor_version`, `confidence`)
- [ ] 3.4 Entity resolver (blocking → cosine ≥ 0.89 → LLM judge → HITL queue)
- [ ] 3.5 Quarantine queue for schema-invalid payloads

## 4. Retrieval & serving

- [ ] 4.1 `/resolve` endpoint — NER + party-id + product-id resolution
- [ ] 4.2 Hybrid retriever (vector + full-text, RRF fusion, k=20)
- [ ] 4.3 Cross-encoder reranker, top-n=5
- [ ] 4.4 GraphRAG Cypher executor using `assets/cypher/10_graphrag_lookup.cypher`
- [ ] 4.5 Two-pass answerer with citation validation
      (`assets/prompts/answerer_system.md`)
- [ ] 4.6 Per-stage latency budgets enforced (see `specs/api/spec.md`)

## 5. Governance

- [ ] 5.1 PII tokenisation pipeline + audit log
- [ ] 5.2 Bitemporal endorsement writer + as-of query helpers
- [ ] 5.3 Evaluation harness with golden set + CI quality gate
- [ ] 5.4 Lineage dashboard (entity → source doc / row)

## 6. Documentation

- [ ] 6.1 Operator runbook
- [ ] 6.2 ER review SOP
- [ ] 6.3 Onboarding guide for new domains (e.g., commercial P&C)
