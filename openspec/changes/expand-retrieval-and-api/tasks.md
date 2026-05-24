# Tasks — expand-retrieval-and-api

## 1. Spec authoring (this change)

- [ ] 1.1 Author MODIFIED + ADDED requirements in
      `specs/retrieval/spec.md` (template catalogue + precedence)
- [ ] 1.2 Author MODIFIED + ADDED requirements in
      `specs/api/spec.md` (ingest / feedback / lineage + payload)
- [ ] 1.3 Author MODIFIED + ADDED requirements in
      `specs/governance/spec.md` (formal metric definitions, baseline
      freezing)

## 2. Implementation backlog (next change)

- [ ] 2.1 Restructure `assets/cypher/` into `templates/` + `tests/`
      and ship `catalog.yaml`
- [ ] 2.2 Add the eight templates listed in design §1.1
- [ ] 2.3 Add one golden test case per template
- [ ] 2.4 Implement the template runner (parameter validation,
      Cypher injection refusal, OTel spans)
- [ ] 2.5 Implement intent classifier + `clarification` payload
- [ ] 2.6 Implement `/v1/ingest`, `/v1/feedback`, `/v1/lineage/{id}`
- [ ] 2.7 Extend `/v1/answer` response with `intent_id`, `template_id`,
      `resolution_layer`, `confidence_floor`
- [ ] 2.8 Wire the metric definitions into the CI harness; freeze the
      first baseline; codify roll-forward checkbox in the PR template
