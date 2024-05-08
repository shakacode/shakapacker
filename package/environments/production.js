/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const { merge } = require("webpack-merge")
const CompressionPlugin = require("compression-webpack-plugin")
const TerserPlugin = require("terser-webpack-plugin")
const baseConfig = require("./base")
const { moduleExists } = require("../utils/helpers")
const config = require("../config")

const getPlugins = () => {
  const plugins = []

  plugins.push(
    new CompressionPlugin({
      filename: "[path][base].gz[query]",
      algorithm: "gzip",
      test: /\.(js|css|html|json|ico|svg|eot|otf|ttf|map)$/
    })
  )

  if ("brotli" in process.versions) {
    plugins.push(
      new CompressionPlugin({
        filename: "[path][base].br[query]",
        algorithm: "brotliCompress",
        test: /\.(js|css|html|json|ico|svg|eot|otf|ttf|map)$/
      })
    )
  }

  return plugins
}

const tryCssMinimizer = () => {
  if (
    moduleExists("css-loader") &&
    moduleExists("css-minimizer-webpack-plugin")
  ) {
    const CssMinimizerPlugin = require("css-minimizer-webpack-plugin")
    return new CssMinimizerPlugin()
  }

  return null
}

const productionConfig = {
  devtool: "source-map",
  stats: "normal",
  bail: true,
  plugins: getPlugins(),
  optimization: {
    minimizer: [
      tryCssMinimizer(),
      new TerserPlugin({
        parallel: Number.parseInt(process.env.SHAKAPACKER_PARALLEL, 10) || true,
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

if (config.useContentHash === false) {
  // eslint-disable-next-line no-console
  console.warn(`⚠️ WARNING
Setting 'useContentHash' to 'false' in the production environment (specified by NODE_ENV environment variable) is not allowed!
Content hashes get added to the filenames regardless of setting useContentHash in 'shakapacker.yml' to false.
`)
}

module.exports = merge(baseConfig, productionConfig)
