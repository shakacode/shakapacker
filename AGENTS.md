# Shakapacker

## Project Overview

Shakapacker is a Ruby gem that integrates webpack/rspack with Rails.

- `lib/`: Ruby gem source code
- `package/`: npm package source code
- `spec/`: RSpec test suite
- `docs/`: usage guides and documentation
- `.claude/commands/`: Claude Code slash commands
- `.claude/rules/`: Claude Code rules
- `prompts/`: shared prompt templates for Codex, GPT, and other non-Claude tools

## Working Rules

- Always use `bundle exec` when running Ruby commands (rubocop, rspec, rake).
- Run `bundle exec rubocop` before committing Ruby changes.
- Run `yarn lint` before committing JavaScript changes.
- Keep PRs small and focused. Never push directly to `main`.
- When the user asks to address PR review comments outside Claude slash commands, follow `prompts/address-review.md`.
