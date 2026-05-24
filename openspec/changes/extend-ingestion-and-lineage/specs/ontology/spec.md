# Delta for Ontology (lineage nodes)

## ADDED Requirements

### Requirement: Document and Chunk lineage labels
The graph SHALL include two ingestion-owned labels:

- `Document` — one node per ingested source file.
  - Required properties: `id` (prefix `DOC_`), `filename`, `mime`,
    `sha256` (content hash), `ingested_at: DateTime`.
  - Optional: `source_system` (when produced by structured ETL),
    `language_hint`, `page_count`.
- `Chunk` — one node per chunk emitted by the chunker.
  - Required properties: `id` (prefix `CH_`), `source_page: Integer`,
    `path: String` (e.g., `"§3.2 / Exclusions"`), `lang: String`,
    `token_count: Integer`, `text: String` (PII-redacted; raw text
    lives in the document store).

Uniqueness constraints on both `Document.id` and `Chunk.id` MUST be
enforced. The `Document.sha256` SHOULD additionally carry a
uniqueness constraint to detect duplicate ingests.

#### Scenario: Duplicate document is detected
- GIVEN a document with `sha256=abcd…` already exists
- WHEN an ingest job submits the same file
- THEN the writer MUST reuse the existing `Document` node
- AND no second `Document` node is created.

### Requirement: Lineage relationships
The closed relationship catalogue is extended with:

- `(:Document)-[:HAS_CHUNK {ordinal: Integer}]->(:Chunk)`
- `(:Clause|:Endorsement|:RiskPeril|:Claim|:Party)
   -[:EXTRACTED_FROM]->(:Chunk)`

Any extracted node MUST carry at least one outgoing `[:EXTRACTED_FROM]`
edge. A node MAY be linked to more than one chunk when its content
was assembled from multiple chunks of the same document.

#### Scenario: Multi-chunk clause is linked to all sources
- GIVEN a clause assembled from chunk `CH_77` and `CH_78`
- WHEN the writer persists the clause
- THEN two `[:EXTRACTED_FROM]` edges exist
- AND the operator can list both chunks via a single graph hop.
