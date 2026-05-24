# Delta for Retrieval (GraphRAG)

## MODIFIED Requirements

### Requirement: As-of graph traversal
The graph traversal SHALL accept an optional `as_of: Date` parameter.
When supplied, the traversal MUST filter:

1. Every endorseable **edge** by
   `valid_from ≤ as_of ≤ coalesce(valid_to, as_of)`.
2. Every mutable **node attribute** by selecting the corresponding
   `*_State` node (`PolicyState`, `PartyState`, `RiskPerilState`)
   whose `[valid_from, valid_to)` range contains `as_of`. The parent
   node's denormalised "latest" projection MUST NOT be used when
   `as_of` is in the past.

The default `as_of` is "now"; in that case the denormalised parent
attributes MAY be used for performance.

#### Scenario: Past status drives the answer
- GIVEN policy `POL_102` whose `status` is currently `Lapsed`
- AND a `PolicyState` shows `status=InForce` for `[2023-01-01,
        2025-02-28]`
- WHEN the retriever runs the GraphRAG lookup with
        `as_of=2024-09-12`
- THEN the resolved policy state used downstream MUST be the `InForce`
       state, not the lapsed parent projection.

#### Scenario: Endorsement-replaced coverage answered correctly
- GIVEN endorsement `END_001` reified `(:Clause)-[:COVERS]->(:RiskPeril)`
        into `(:Clause)-[:HAS_COVERAGE]->(:Coverage)-[:FOR_PERIL]->
        (:RiskPeril)` effective 2025-06-01
- WHEN the retriever runs the lookup with `as_of=2025-03-15`
- THEN the original `[:COVERS]` edge (still `is_active=true` on that
       date) is used
- AND the reified `Coverage` node is skipped.
