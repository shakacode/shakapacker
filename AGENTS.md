# AGENTS.md

Canonical agent instructions for Shakapacker.

> Project guidelines currently also live in `CLAUDE.md`; consolidating them here
> (and slimming `CLAUDE.md` to `@AGENTS.md`) is a planned follow-up.

## Agent Workflow Configuration

Portable shared skills (from
[`shakacode/agent-workflows`](https://github.com/shakacode/agent-workflows))
resolve this repo's commands and policy through this section. When a skill says
"run the repo's local validation" or "use the hosted-CI trigger," the concrete
value is here.

- **Base branch**: `main`.
- **Setup / dependency install**: `.agents/bin/setup` (`bundle install` and
  `yarn install`).
- **Pre-push local validation**: `.agents/bin/validate` (runs `.agents/bin/lint`
  and `.agents/bin/test`).
- **CI change detector**: `n/a`.
- **Hosted-CI trigger**: `n/a` — CI runs on every PR.
- **CI parity environment**: `n/a` — reproduce CI-only failures from the matching
  job in `.github/workflows/**`.
- **Benchmark labels**: `n/a`.
- **Follow-up issue prefix**: `Follow-up:`.
- **Changelog**: `CHANGELOG.md` — user-visible changes only.
- **Lint / format**: `.agents/bin/lint` (`bundle exec rubocop`, plus
  `yarn lint`; pass `-A` through to RuboCop when autocorrect is intended).
- **Merge ledger**: `n/a`.
- **Docs checks**: `n/a` unless the touched docs define their own focused check.
- **Tests**: `.agents/bin/test` (`bundle exec rake test` and
  `yarn test --runInBand`).
- **Build / type checks**: `.agents/bin/build` (`yarn build` and
  `yarn type-check`).
- **Review gate**: AI reviewers are advisory unless they confirm a blocker; the
  merge gate is the full `gh pr checks` list green, all review threads resolved,
  and mergeable clean.
- **Approval-exempt change categories**: at batch closeout, auto-merge ready
  low-risk PRs that pass the merge gate; keep high-risk changes
  (CI/workflow, build-config, dependency or runtime bumps, broad refactors, and
  release work) maintainer-gated.
- **Coordination backend**: private `shakacode/agent-coordination`
  (claims/heartbeats namespaced by full repo name).

Validate this seam with:

```bash
agent-workflow-seam-doctor --shared /path/to/agent-workflows
```

Non-command compatibility values may also exist in
[`.agents/agent-workflow.yml`](.agents/agent-workflow.yml), but `AGENTS.md` is
the canonical seam for shared workflow skills.
