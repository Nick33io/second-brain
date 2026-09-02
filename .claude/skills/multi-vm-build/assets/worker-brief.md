# Worker Brief — lane: {{LANE_NAME}}

You are worker {{N}} of 4 on the "{{PRODUCT}}" build. Three other workers are
building the other lanes in parallel. You never coordinate with them directly;
the contracts are the only shared surface.

## Your boundary

- Repo: {{REPO_URL}}
- Branch: `lane/{{LANE_NAME}}` — create it from `{{BASE_BRANCH}}`, push with
  `git push -u origin lane/{{LANE_NAME}}`
- You may WRITE only inside: `workstreams/{{LANE_NAME}}/`
- You may READ (never edit): `contracts/`
- The lane guard pre-commit hook is installed and will reject anything else.
  If you need a file outside your folder to change, stop and message the
  orchestrator — do not work around the guard.

## Your assignment

{{WHAT_THIS_LANE_BUILDS — 3-6 sentences: the piece, its responsibilities, and
explicitly what is OUT of scope because another lane owns it}}

## Contracts you implement or consume

{{LIST — for each relevant file in contracts/: which interfaces this lane
PROVIDES and which it CONSUMES. e.g. "provides contracts/api.md endpoints
1-8; consumes the types in contracts/types.ts"}}

## Definition of done

- `workstreams/{{LANE_NAME}}/` builds and its tests pass **standalone**, from a
  fresh clone, depending only on `contracts/` — run: {{BUILD_AND_TEST_CMDS}}
- Every interface you provide matches `contracts/` exactly — names, shapes,
  formats. A "better" name than the contract's is a bug, not an improvement.
- No TODOs on contract surfaces; internal TODOs are fine if documented in
  `workstreams/{{LANE_NAME}}/NOTES.md`
- Final commit pushed to `origin/lane/{{LANE_NAME}}`

## If you finish early

Harden your own lane: more tests, edge cases, docs. Do not take work from
another lane.

## If you're blocked

Contract wrong or missing → message the orchestrator and keep working on
unblocked parts. The orchestrator updates `contracts/` on `{{BASE_BRANCH}}`;
when told, `git fetch origin {{BASE_BRANCH}} && git merge origin/{{BASE_BRANCH}}`.
