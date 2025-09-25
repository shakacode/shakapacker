/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const { resolve } = require("path")
const { merge } = require("webpack-merge")
const baseConfig = require("./base")
const { moduleExists } = require("../utils/helpers")
const config = require("../config")

const optimizationPath = resolve(
  __dirname,
  "..",
  "optimization",
  `${config.assets_bundler}.js`
)
const { getOptimization } = require(optimizationPath)

let CompressionPlugin = null
if (moduleExists("compression-webpack-plugin")) {
  // eslint-disable-next-line global-require
  CompressionPlugin = require("compression-webpack-plugin")
}

const getPlugins = () => {
  const plugins = []

  if (CompressionPlugin) {
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
  }

  return plugins
}

const productionConfig = {
  devtool: "source-map",
  stats: "normal",
  bail: true,
  plugins: getPlugins(),
  optimization: getOptimization()
}

if (config.useContentHash === false) {
  // eslint-disable-next-line no-console
  console.warn(`⚠️ WARNING
Setting 'useContentHash' to 'false' in the production environment (specified by NODE_ENV environment variable) is not allowed!
Content hashes get added to the filenames regardless of setting useContentHash in 'shakapacker.yml' to false.
`)
}

module.exports = merge(baseConfig, productionConfig)
