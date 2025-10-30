/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
const config = require("../config")

const requireOrError = (moduleName: string): any => {
  try {
    return require(moduleName)
  } catch (originalError) {
    const error = new Error(
      `[SHAKAPACKER]: ${moduleName} is required for ${config.assets_bundler} but is not installed. View Shakapacker's documented dependencies at https://github.com/shakacode/shakapacker/tree/main/docs/peer-dependencies.md`
    )
    // Add the original error as the cause for better debugging (ES2022+)
    // Using type assertion since target is ES2020 but runtime supports it
    ;(error as any).cause = originalError
    throw error
  }
}

export = { requireOrError }
