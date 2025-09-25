const { requireOrError } = require("../utils/requireOrError")

const rspack = requireOrError("@rspack/core")

const getOptimization = () => {
  // Use Rspack's built-in minification instead of terser-webpack-plugin
  const result = { minimize: true }
  try {
    result.minimizer = [
      new rspack.SwcJsMinimizerRspackPlugin(),
      new rspack.LightningCssMinimizerRspackPlugin()
    ]
  } catch (error) {
    // eslint-disable-next-line no-console
    console.warn(
      "[SHAKAPACKER]: Warning: Could not configure Rspack minimizers:",
      error.message
    )
  }
  return result
}

module.exports = {
  getOptimization
}
