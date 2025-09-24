/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
const config = require("../config")

const requireOrError = (moduleName) => {
  try {
    return require(moduleName)
  } catch (error) {
    throw new Error(
      `[SHAKAPACKER]: ${moduleName} is required for ${config.bundler} but is not installed. View Shakapacker's documented dependencies at https://github.com/shakacode/shakapacker/tree/main/docs/peer-dependencies.md`
    )
  }
}

module.exports = { requireOrError }
