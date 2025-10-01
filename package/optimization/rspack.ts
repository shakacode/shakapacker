const { requireOrError } = require("../utils/requireOrError")
const { error: logError } = require("../utils/debug")

const rspack = requireOrError("@rspack/core")

const getOptimization = () => {
  // Use Rspack's built-in minification instead of terser-webpack-plugin
  const result: { minimize: boolean; minimizer?: any[] } = { minimize: true }
  try {
    result.minimizer = [
      new rspack.SwcJsMinimizerRspackPlugin(),
      new rspack.LightningCssMinimizerRspackPlugin()
    ]
  } catch (error: any) {
    // Log full error with stack trace
    logError(
      `Failed to configure Rspack minimizers: ${error.message}\n${error.stack}`
    )
    // Re-throw the error to properly propagate it
    throw new Error(
      `Could not configure Rspack minimizers: ${error.message}. Please check that @rspack/core is properly installed.`
    )
  }
  return result
}

export = {
  getOptimization
}
