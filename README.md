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
│   └── architecture-optimizations.md       # Deviations & rationale
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
