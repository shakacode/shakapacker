# AGENTS.md

Canonical agent instructions for Shakapacker.

> Project guidelines currently also live in `CLAUDE.md`; consolidating them here
> (and slimming `CLAUDE.md` to `@AGENTS.md`) is a planned follow-up.

## Agent Workflow Configuration

Portable shared skills resolve this repo's commands and policy through:
- **Commands** — run `.agents/bin/<name>` (`setup`, `validate`, `test`, ...); see `.agents/bin/README.md`. A missing script means that capability is n/a here.
- **Policy / config** — `.agents/agent-workflow.yml`.
