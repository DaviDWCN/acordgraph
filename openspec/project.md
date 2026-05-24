# Project Context — acordgraph

## Mission
Build a production-grade **Insurance Knowledge Graph** aligned with the
**ACORD Information Model (AIM v2.x)** and exposed through a **GraphRAG**
(Graph-augmented Retrieval-Augmented Generation) service so that downstream
underwriting, policy-servicing and claims assistants can answer multi-hop
contractual questions deterministically.

## Target Architecture (one-liner)
Neo4j (Labeled Property Graph) + native Vector Index + LLM extraction pipeline
+ Hybrid (graph ⨯ vector) retrieval API → grounded LLM answers with citation
paths.

## Stage Scope
This repository is currently in the **Requirements & Architecture** stage.
No runtime code is produced yet; only:
1. OpenSpec change proposal(s) under `openspec/changes/`
2. Authoritative technical specification under `docs/`
3. Reference assets (Cypher DDL, JSON Schema, prompt templates) under
   `assets/` that downstream implementation changes will consume verbatim.

## Conventions
- **Spec authoring**: follow OpenSpec — every requirement uses
  `### Requirement:` headings with at least one `#### Scenario:` block in
  GIVEN / WHEN / THEN form.
- **Identifier conventions**: all node `id` properties are stable, opaque
  strings prefixed by entity-type (`P_`, `POL_`, `CL_`, `CLM_`, `SUB_`,
  `PER_`, `PROD_`). External business keys (`policy_number`,
  `claim_number`, `icd_code`) are modelled as separate indexed properties.
- **Language**: documentation may be authored in English or Simplified
  Chinese; embeddings and clause text MUST preserve original language and
  store ISO 639-1 `lang` on `Clause` nodes.
- **Versioning**: bitemporal — every relationship that can be amended via
  endorsement carries `valid_from`, `valid_to`, `is_active`; specs are
  versioned through OpenSpec change archives.

## Out of Scope (this stage)
- Production code (ETL, API server, UI)
- Vendor selection for LLM provider, embedding model, observability stack
- Concrete SLA numbers (placeholders only; finalised in a future change)
