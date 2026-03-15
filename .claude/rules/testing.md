# Testing Rules

1. Run corresponding specs/tests when changing source files.
2. Run `bundle exec rubocop` before committing Ruby changes.
3. Run `yarn lint` before committing JavaScript changes.
4. Prefer explicit RSpec spy assertions (`have_received`) over indirect counters.
5. Validate both webpack and rspack paths when changing core Shakapacker behavior.
