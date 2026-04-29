// This thin re-export targets `shakapacker/rspack`, which resolves to the
// compiled `package/rspack/index.js`. In a published install this is built by
// `prepublishOnly`; for local monorepo development run `yarn build` in the
// repository root before consuming this package against the source tree.
module.exports = require("shakapacker/rspack")
