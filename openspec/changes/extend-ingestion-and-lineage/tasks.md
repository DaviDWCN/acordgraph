# Tasks — extend-ingestion-and-lineage

## 1. Spec authoring (this change)

- [ ] 1.1 Author MODIFIED + ADDED requirements in
      `specs/ingestion/spec.md`
- [ ] 1.2 Author ADDED requirements in `specs/ontology/spec.md`
      (Document / Chunk + edges)
- [ ] 1.3 Author MODIFIED requirements in `specs/governance/spec.md`
      (lineage traversal, staged band)
- [ ] 1.4 Cross-reference into `docs/acord-mapping.md` (add Document/
      Chunk rows under "Reference & infrastructure")

## 2. Implementation backlog (next change)

- [ ] 2.1 Split extraction.schema.json into three profile-bound schemas
      (or one schema with discriminator on `profile`)
- [ ] 2.2 Update `assets/prompts/extractor_system.md` with
      `<UNTRUSTED_INPUT>` framing and numeric re-verification rule
- [ ] 2.3 Implement deterministic id generator helper + tests
- [ ] 2.4 Add `Document` / `Chunk` constraints and indexes to
      `assets/cypher/01_constraints_indexes.cypher`
- [ ] 2.5 Make fulltext index creation conditional on a CJK env flag
- [ ] 2.6 Wire numeric re-verification into the writer (regex set per
      field) with confidence demotion path
- [ ] 2.7 Implement `:Staged` label + `staged_until` TTL sweeper
- [ ] 2.8 Migration: backfill `[:EXTRACTED_FROM]` links from existing
      `source_doc_id` / `source_page` properties
