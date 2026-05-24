# acordgraph

ACORD-aligned **Insurance Knowledge Graph** with a **GraphRAG** (graph-
augmented retrieval-augmented generation) serving layer.

> **Stage:** Requirements & Architecture — no runtime code yet.
> Specifications are authored using the [OpenSpec](https://github.com/Fission-AI/OpenSpec)
> conventions.

## Repository layout

```
acordgraph/
├── openspec/
│   ├── project.md                          # Project context for OpenSpec
│   └── changes/
│       └── bootstrap-acord-kg/             # First change (greenfield)
│           ├── proposal.md                 # Why & what
│           ├── design.md                   # How & best-practice upgrades
│           ├── tasks.md                    # Implementation backlog
│           └── specs/                      # Delta specs per domain
│               ├── ontology/spec.md
│               ├── ingestion/spec.md
│               ├── retrieval/spec.md
│               ├── governance/spec.md
│               └── api/spec.md
├── docs/
│   ├── technical-spec.md                   # Inbound brief v1.1 (verbatim)
│   ├── architecture-optimizations.md       # Deviations & rationale
│   ├── acord-mapping.md                    # ACORD AIM ↔ graph element map
│   └── glossary.md                         # Canonical term definitions
└── assets/
    ├── cypher/
    │   ├── 01_constraints_indexes.cypher   # Schema bootstrap (Neo4j 5.13+)
    │   └── 10_graphrag_lookup.cypher       # Parameterised retrieval query
    ├── prompts/
    │   ├── extractor_system.md             # LLM extraction System Prompt
    │   └── answerer_system.md              # Grounded answer System Prompt
    └── schemas/
        └── extraction.schema.json          # JSON Schema for extractor output
```

## Where to start

| You want to…                              | Read…                                                  |
|-------------------------------------------|--------------------------------------------------------|
| Understand the project at a glance        | `openspec/project.md`                                  |
| See the original brief                    | `docs/technical-spec.md`                               |
| Understand the upgrades over the brief    | `docs/architecture-optimizations.md`                   |
| Review formal requirements                | `openspec/changes/bootstrap-acord-kg/specs/*/spec.md`  |
| See what the next change must build       | `openspec/changes/bootstrap-acord-kg/tasks.md`         |
| Pull schema / queries / prompts as-is     | `assets/`                                              |

## Next change

The next OpenSpec change (`implement-acord-kg`) will:
1. Stand up the Neo4j instance and apply `assets/cypher/01_constraints_indexes.cypher`.
2. Build the ingestion pipelines (structured ETL + LLM extraction).
3. Implement the GraphRAG serving layer per `specs/api/spec.md`.
4. Wire the evaluation harness and CI quality gate.

## Follow-up requirement & architecture changes

Four documentation-only OpenSpec changes refine the bootstrap before
any code is written. They are ordered; each builds on the previous.

| # | Change ID                              | Focus                                                                                          |
|---|----------------------------------------|------------------------------------------------------------------------------------------------|
| 1 | `harden-ontology-and-temporality`      | Endorsement / Coverage reification, Subject subtypes, state nodes, generic peril coding, configurable embedding dim. |
| 2 | `extend-ingestion-and-lineage`         | Extractor profiles (wording / claim-form / endorsement), prompt-injection isolation, numeric re-verification, `:Document` / `:Chunk` lineage. |
| 3 | `expand-retrieval-and-api`             | Cypher Template Catalogue + `intent_id`, 4-layer precedence (Endorsement > Rider > Excl > Cover), `/v1/ingest`, `/v1/feedback`, `/v1/lineage/{id}`, formal CI metric definitions. |
| 4 | `governance-pii-and-sla`               | Extended PII coverage (Chunk.text, embeddings, filenames), embedding-inversion defence, FX policy, availability / RPO / RTO SLOs, super-node guard, dual-write index rebuild. |

Each change lives in `openspec/changes/<change-id>/` with its
`proposal.md`, `design.md`, `tasks.md`, and per-capability delta
`specs/<capability>/spec.md`. Definitions of all domain terms used
across these documents are in `docs/glossary.md`; the ACORD-to-graph
mapping is in `docs/acord-mapping.md`.
