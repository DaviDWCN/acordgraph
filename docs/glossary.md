# Glossary

A single source of truth for terms used across `openspec/` and
`docs/`. When a term in this glossary is used in a spec, it MUST
carry the meaning defined here.

## Domain & ontology

- **ACORD / AIM v2.x** — The ACORD Information Model, a global
  insurance-industry data standard. Pillars: `Party`, `Agreement`,
  `Subject`, `Claim`.
- **LPG (Labeled Property Graph)** — The graph model used by Neo4j:
  nodes carry one or more labels plus properties; edges are typed
  and may carry properties.
- **Endorsement** — A contractual amendment to a `Policy`. Modelled
  as a first-class node and as a property carried on the closed /
  superseding edges it produced.
- **Rider** — A sub-product attached to a base `InsuranceProduct` via
  `[:RIDES_ON]`. May reinstate a peril otherwise excluded by the base
  product.
- **Coverage (reified)** — A first-class `:Coverage` node replacing
  the `[:COVERS]` edge when a per-policy override (endorsement,
  rider, divergent runtime numbers) requires it.
- **Subject (super-label)** — `:Subject` plus exactly one subtype
  label `:PersonSubject` | `:VehicleSubject` | `:PropertySubject`.
- **State node** — A reified history record of a node's mutable
  attributes (`PolicyState`, `PartyState`, `RiskPerilState`),
  linked via `[:HAS_STATE]`.

## Temporality

- **Bitemporal** — Two time axes are tracked: `valid_from / valid_to`
  (when the fact was true in the world) and `recorded_at` (when the
  fact was learned by the system).
- **As-of query** — A retrieval that filters edges and state nodes by
  a supplied `as_of: Date`.
- **`is_active`** — A derived flag on endorseable edges: equal to
  `(valid_to IS NULL OR valid_to > now())`. Writers MUST NOT set it
  independently.

## Ingestion

- **Profile** — A bound `(allowed_labels, allowed_edges)` set that an
  extractor invocation cannot escape. Profiles: `wording`,
  `claim-form`, `endorsement`.
- **Chunk** — A single text fragment produced by the chunker.
  Heading-aware, ≤ 1500 tokens, ≤ 15% overlap. Modelled as a
  `:Chunk` node.
- **Document** — One source file. Modelled as a `:Document` node with
  content hash and ingestion metadata.
- **`[:EXTRACTED_FROM]`** — The lineage edge from any extracted node
  to the `:Chunk` it came from.
- **Quarantine** — An out-of-graph store for payloads that failed
  schema validation, ER conflicts, missing provenance, or expired
  `:Staged` TTL.
- **HITL (Human-in-the-loop)** — A review queue for cases the
  automated entity resolver routes for human adjudication (cosine
  similarity in the 0.80–0.89 band, low-confidence extractions, etc.).
- **`:Staged`** — Secondary label on nodes with confidence in
  `[0.60, 0.80)`. Invisible to retrieval. TTL default 30 days.

## Retrieval

- **GraphRAG** — Graph-augmented retrieval-augmented generation. The
  knowledge graph is the authoritative reasoner; vector / lexical
  recall serve only as candidate generators.
- **RRF (Reciprocal Rank Fusion)** — A rank-fusion algorithm
  combining vector and lexical candidate lists.
- **Cross-encoder rerank** — A model that scores `(query, document)`
  pairs jointly, used to reduce a fused candidate list to the top-5.
- **Cypher Template Catalogue** — The closed set of executable
  `.cypher` files registered in `assets/cypher/catalog.yaml`. The
  only sanctioned source of queries; LLM-generated Cypher is
  forbidden in production.
- **Intent id** — A stable string identifying a query class; maps
  one-to-one to a template in the catalogue.
- **Resolution layer (L1–L4)** — The precedence layer (Endorsement /
  Rider / base-Exclusion / base-Coverage) that produced an answer's
  verdict.
- **Two-pass answerer** — The LLM emits a JSON of cited facts; a
  deterministic renderer validates that every cited `clause_id`
  exists in the retrieved sub-graph before producing the user-visible
  answer.

## Governance & evaluation

- **Provenance** — The minimum fields `extractor_version`,
  `confidence`, and lineage edge `[:EXTRACTED_FROM]` for unstructured
  inputs; `source_system` / `source_record_id` for structured ETL.
- **Golden set** — A versioned collection of
  question → expected-subgraph pairs used by the CI metric harness.
- **`recall@5`, `citation_precision`, `faithfulness`,
  `subgraph_overlap_f1`** — The four metrics gating CI; see
  `expand-retrieval-and-api/specs/governance/spec.md` for formal
  definitions.
- **Baseline freezing** — The discipline of comparing each PR's
  metrics against the metric vector recorded by the last cleanly
  archived change. Regressions block merge unless an explicit
  Baseline Roll-Forward section is approved.
- **Confidence band** — `<0.60` blocked / `0.60–0.80` staged / `≥0.80`
  active.

## Security & PII

- **PII token** — A surrogate value stored in the graph in place of
  the raw personal identifier. The mapping lives in a separate
  access-controlled vault.
- **Embedding inversion** — A class of attacks that reconstructs text
  fragments from an embedding vector. Mitigated by embedding only the
  PII-redacted form.
- **Row-level authorisation** — Per-row entitlement checks on serving
  endpoints; unauthorised callers receive `404`, not `403`, so the
  existence of a row is not leaked.

## Operations

- **SLO** — Service-Level Objective (the internal commitment).
- **RPO / RTO** — Recovery Point Objective (max acceptable data
  loss) / Recovery Time Objective (max acceptable downtime).
- **Super-node guard** — An alert raised when a single node
  accumulates incoming edges beyond a threshold (default 5 × 10⁵).
- **Dual-write index rebuild** — Reads continue from the previous
  index version until the new version reports `ONLINE`.
