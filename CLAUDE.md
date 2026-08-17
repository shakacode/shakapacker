@AGENTS.md

# Claude-Specific Guidance

## Conductor Environment

These notes remain here because they apply only to Claude Code sessions running
through Conductor. Shared project policy lives in `AGENTS.md`.

- The setup script detects mise, asdf, or direct `PATH` tools such as rbenv,
  nvm, and nodenv.
- Use `bin/conductor-exec` when tool versions are not detected correctly in
  Conductor's non-interactive shell. For example:
  `bin/conductor-exec bundle exec rubocop`.
- The wrapper uses `mise exec` when mise is available and otherwise falls back
  to direct execution.
- `conductor.json` scripts already use this wrapper, so it is not normally
  needed manually.
