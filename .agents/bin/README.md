# Agent Workflow Scripts

Repo-owned helper scripts for agent workflows. Shaka's `setup`, `test`, and
`validate` commands live in [`../shaka/bin/`](../shaka/bin/); see
[`../shaka.md`](../shaka.md).

| Script                  | Purpose                                  | This repo runs                                                                                                     |
| ----------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `lint`                  | Lint / format (pass `-A` to fix RuboCop) | `bundle exec rubocop` + `yarn lint` (eslint)                                                                       |
| `build`                 | Build / type-check                       | `yarn build` + `yarn type-check`                                                                                   |
| `merge-readiness-check` | Pre-merge/replay readiness check         | Verifies full `gh pr checks` completion, unresolved review threads, mergeability, and historical post-merge timing |
