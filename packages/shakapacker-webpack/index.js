// This thin re-export forwards to the core `shakapacker` package. The value
// is in this package's tighter peer-dependency declarations, not the runtime
// surface; see packages/shakapacker-webpack/package.json. For local monorepo
// development run `yarn build` in the repository root first.
module.exports = require("shakapacker")
