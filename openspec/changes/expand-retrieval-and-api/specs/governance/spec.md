# Delta for Governance & QA (formal metrics)

## MODIFIED Requirements

### Requirement: Evaluation harness gating
The CI evaluation harness SHALL be executed on every change that
touches prompts, schema, ontology, retrieval logic, or the Cypher
catalogue. The harness MUST run with deterministic settings (LLM
temperature = 0, fixed embedding-cache, fixed reranker checkpoint,
fixed sampling seed) and compute, at minimum:

| Metric                  | Definition |
|-------------------------|------------|
| `recall@5`              | Over the golden set Q, the average of `|expected_clause_ids ∩ top5_reranked_ids| / |expected_clause_ids|`. |
| `citation_precision`    | Over answered Q, the average of `|cited_clause_ids ∩ retrieved_subgraph_clause_ids| / |cited_clause_ids|`. |
| `faithfulness`          | Ragas `faithfulness` of `answer_text` against the textualised retrieved sub-graph. |
| `subgraph_overlap_f1`   | F1 between the produced sub-graph node-id set and the expected sub-graph node-id set, weighted by node label (clause: 1.0, peril: 0.7, coverage: 0.7, other: 0.3). |

The build MUST fail if **any** of:

- `recall@5` drops by more than **0.02** absolute points vs the
  frozen baseline,
- `citation_precision` falls below **0.95** absolute,
- `faithfulness` falls below **0.90** absolute,
- `subgraph_overlap_f1` drops by more than **0.03** absolute points
  vs the frozen baseline.

#### Scenario: Recall regression blocks merge
- GIVEN the baseline `recall@5` is 0.82
- WHEN a change pushes `recall@5` to 0.79
- THEN the harness MUST report a failure
- AND the change cannot be archived until the metric is restored or
       the baseline is explicitly rolled forward (see "Baseline
       management" below).

## ADDED Requirements

### Requirement: Baseline management
The metric baseline is the metric vector recorded by the most
recently archived change that ran the harness clean. Rolling the
baseline forward (i.e., accepting a regression as intentional) SHALL
require:

1. A dedicated `Baseline Roll-Forward` section in the change's
   `proposal.md` listing each affected metric, the old value, the new
   value, and the justification.
2. A reviewer sign-off explicitly approving the roll-forward.
3. The harness output (machine-readable) committed under
   `assets/eval/baseline.json` in the same change.

CI MUST refuse to advance the baseline unless all three artefacts
are present.

#### Scenario: Roll-forward requires sign-off
- GIVEN a change reduces `recall@5` from 0.82 to 0.80
- AND `proposal.md` does not contain a `Baseline Roll-Forward` section
- WHEN CI runs
- THEN the build MUST fail
- AND the change cannot be archived.

### Requirement: Feedback ingestion into the golden set
The golden set SHALL be refreshable from feedback rows captured by
`/v1/feedback`. The refresh process is a tracked OpenSpec change of
its own ("refresh-golden-set-YYYY-MM"); it MUST:

1. List every feedback row consumed (by `answer_id`).
2. Show the metric impact of the candidate additions on the baseline
   *before* the refresh is applied.
3. Be archived only after governance sign-off.

#### Scenario: Refresh transparency
- GIVEN 17 feedback rows accumulated in a quarter
- WHEN the refresh change is proposed
- THEN its `proposal.md` lists all 17 `answer_id`s
- AND the metric-impact table shows pre/post values for each metric.
