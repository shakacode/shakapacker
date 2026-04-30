// This thin re-export targets `shakapacker/rspack`, which resolves to the
// compiled `package/rspack/index.js`. The compiled core is built by the
// upstream `shakapacker` package's `prepublishOnly`; for local monorepo
// development run `yarn build` in the repository root before consuming this
// package against the source tree.
module.exports = require("shakapacker/rspack")
