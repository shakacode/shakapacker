# Shakapacker Project Guidelines

## Critical Requirements

- **ALWAYS end all files with a trailing newline character.** This is required by the project's linting rules.
- **ALWAYS use `bundle exec` prefix when running Ruby commands** (rubocop, rspec, rake, etc.)
- **ALWAYS run `bundle exec rubocop` before committing Ruby changes**
- **ALWAYS run `yarn lint` before committing JavaScript changes**

## Testing

- Run corresponding RSpec tests when changing source files
- For example, when changing `lib/shakapacker/foo.rb`, run `spec/shakapacker/foo_spec.rb`
- Run the full test suite with `bundle exec rspec` before pushing

## Code Style

- Follow existing code conventions in the file you're editing
- Use the project's existing patterns and utilities
- No unnecessary comments unless requested
- Keep changes focused and minimal - avoid extraneous diffs

## Git Workflow

- Create feature branches for all changes
- Never push directly to main branch
- Create small, focused PRs that are easy to review
- Always create a PR immediately after pushing changes

## Changelog

- **Update CHANGELOG.md for user-visible changes only**
- User-visible changes include: new features, bug fixes, breaking changes, deprecations, performance improvements
- **Do NOT add changelog entries for**: linting fixes, code formatting, internal refactoring, test updates, documentation fixes
- Non-user-visible changes don't need changelog entries even if they modify code
- **Format requirements**:
  - Always link to the PR: `[PR #123](https://github.com/shakacode/shakapacker/pull/123)`
  - Always link to the author: `by [username](https://github.com/username)`
  - Keep formatting consistent with existing entries
  - When releasing a version, update the version diff links at the bottom of CHANGELOG.md

## Shakapacker-Specific

- This gem supports both webpack and rspack configurations
- Test changes with both bundlers when modifying core functionality
- Be aware of the dual package.json/Gemfile dependency management
