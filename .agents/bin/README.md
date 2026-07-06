# Agent Workflow Scripts

Standard entry points that portable agent-workflow skills call, so a skill can
run `.agents/bin/<name>` in any repo without knowing this repo's specific
commands. Each script is a thin, repo-owned wrapper. A script that is **absent**
means that capability is n/a here.

| Script                  | Purpose                                  | This repo runs                                                                                                     |
| ----------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `setup`                 | Install dependencies                     | `bundle install` + `yarn install`                                                                                  |
| `validate`              | Pre-push gate (run before pushing)       | `lint` + `test`                                                                                                    |
| `test`                  | Run tests                                | `bundle exec rake test` (rspec) + `yarn test --runInBand` (jest)                                                   |
| `lint`                  | Lint / format (pass `-A` to fix RuboCop) | `bundle exec rubocop` + `yarn lint` (eslint)                                                                       |
| `build`                 | Build / type-check                       | `yarn build` + `yarn type-check`                                                                                   |
| `merge-readiness-check` | Pre-merge/replay readiness check         | Verifies full `gh pr checks` completion, unresolved review threads, mergeability, and historical post-merge timing |

Canonical non-command policy lives in [`../../AGENTS.md`](../../AGENTS.md).
[`../agent-workflow.yml`](../agent-workflow.yml) is retained only as a
compatibility summary for older workflow copies.
