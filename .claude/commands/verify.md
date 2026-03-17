---
description: Run the standard project verification loop before pushing.
---

Run the following checks in order and stop on first failure:

1. `bundle exec rubocop`
2. `yarn lint`
3. `bundle exec rspec`
4. `yarn test --runInBand` (serial mode for reliable pre-push verification)

If all checks pass, summarize command outcomes and total runtime.
