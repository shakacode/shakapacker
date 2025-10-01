const { requireOrError } = require("../utils/requireOrError")

const TerserPlugin = requireOrError("terser-webpack-plugin")
const { moduleExists } = require("../utils/helpers")

const tryCssMinimizer = () => {
  if (
    moduleExists("css-loader") &&
    moduleExists("css-minimizer-webpack-plugin")
  ) {
    const CssMinimizerPlugin = requireOrError("css-minimizer-webpack-plugin")
    return new CssMinimizerPlugin()
  }

  return null
}

const getOptimization = () => {
  return {
    minimizer: [
      tryCssMinimizer(),
      new TerserPlugin({
        // Parse SHAKAPACKER_PARALLEL env var to number, fallback to true for parallel execution
        // Empty string ensures parseInt returns NaN when env var is undefined, then || true applies
        parallel: Number.parseInt(process.env.SHAKAPACKER_PARALLEL || "", 10) || true,
        terserOptions: {
          parse: {
            // Let terser parse ecma 8 code but always output
            // ES5 compliant code for older browsers
            ecma: 8
          },
          compress: {
            ecma: 5,
            warnings: false,
            comparisons: false
          },
          mangle: { safari10: true },
          output: {
            ecma: 5,
            comments: false,
            ascii_only: true
          }
        }
      })
    ].filter(Boolean)
  }
}

export = {
  getOptimization
}
