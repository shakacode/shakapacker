const { requireOrError } = require("../utils/requireOrError")

const TerserPlugin = requireOrError("terser-webpack-plugin")
const { moduleExists } = require("../utils/helpers")

const tryCssMinimizer = (): unknown | null => {
  if (
    moduleExists("css-loader") &&
    moduleExists("css-minimizer-webpack-plugin")
  ) {
    const CssMinimizerPlugin = requireOrError("css-minimizer-webpack-plugin")
    return new CssMinimizerPlugin()
  }

  return null
}

interface OptimizationConfig {
  minimizer: unknown[]
}

const getOptimization = (): OptimizationConfig => {
  return {
    minimizer: [
      tryCssMinimizer(),
      new TerserPlugin({
        // Parse SHAKAPACKER_PARALLEL env var to number, fallback to true for parallel execution
        // If env var is set and is a valid number, use it; otherwise default to true (parallel enabled)
        parallel: (() => {
          const parallelEnv = process.env.SHAKAPACKER_PARALLEL
          if (!parallelEnv) return true
          const parsed = Number.parseInt(parallelEnv, 10)
          return Number.isNaN(parsed) ? true : parsed
        })(),
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
