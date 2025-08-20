const { merge } = require("webpack-merge")
const { rspack } = require("@rspack/core")

const baseConfig = require("./base")
const { moduleExists } = require("../../utils/helpers")

let CompressionPlugin = null
if (moduleExists("compression-webpack-plugin")) {
  // eslint-disable-next-line global-require
  CompressionPlugin = require("compression-webpack-plugin")
}

const productionConfig = {
  mode: "production",
  devtool: "source-map",
  bail: true
}

const plugins = []

if (CompressionPlugin) {
  plugins.push(
    new CompressionPlugin({
      filename: "[path][base].gz[query]",
      algorithm: "gzip",
      test: /\.(js|css|html|json|ico|svg|eot|otf|ttf|map)$/,
      threshold: 8192,
      minRatio: 0.8
    })
  )
}

// Use Rspack's built-in minification instead of terser-webpack-plugin
try {
  productionConfig.optimization = {
    minimize: true,
    minimizer: [
      new rspack.SwcJsMinimizerRspackPlugin(),
      new rspack.LightningCssMinimizerRspackPlugin()
    ]
  }
} catch (error) {
  // eslint-disable-next-line no-console
  console.warn("Warning: Could not configure Rspack minimizers:", error.message)
  productionConfig.optimization = {
    minimize: true
  }
}

if (plugins.length > 0) {
  productionConfig.plugins = plugins
}

module.exports = merge(baseConfig, productionConfig)
