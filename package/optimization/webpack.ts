import requireOrError from "../utils/requireOrError"
import { moduleExists } from "../utils/helpers"

interface TerserPluginConstructor {
  new (options: unknown): unknown
}

interface CssMinimizerPluginConstructor {
  new (): unknown
}

const TerserPlugin = requireOrError(
  "terser-webpack-plugin"
) as TerserPluginConstructor

const tryCssMinimizer = (): unknown | null => {
  if (
    moduleExists("css-loader") &&
    moduleExists("css-minimizer-webpack-plugin")
  ) {
    const CssMinimizerPlugin = requireOrError(
      "css-minimizer-webpack-plugin"
    ) as CssMinimizerPluginConstructor
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
        // SHAKAPACKER_PARALLEL env var: number of parallel workers, or true for auto (os.cpus().length - 1)
        // If not set or invalid, defaults to true (automatic parallelization)
        parallel: process.env.SHAKAPACKER_PARALLEL
          ? Number.parseInt(process.env.SHAKAPACKER_PARALLEL, 10) || true
          : true,
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

export { getOptimization }
