const { merge } = require("webpack-merge")
const { rspack } = require("@rspack/core")

const baseConfig = require("./base")
const { moduleExists } = require("../../utils/helpers")

const productionConfig = {
  mode: "production",
  devtool: "source-map",
  bail: true
}

const plugins = []

if (moduleExists("compression-webpack-plugin")) {
  const CompressionPlugin = require("compression-webpack-plugin")
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
productionConfig.optimization = {
  minimize: true,
  minimizer: [
    new rspack.SwcJsMinimizerRspackPlugin(),
    new rspack.SwcCssMinimizerRspackPlugin()
  ]
}

if (plugins.length > 0) {
  productionConfig.plugins = plugins
}

module.exports = merge(baseConfig, productionConfig)