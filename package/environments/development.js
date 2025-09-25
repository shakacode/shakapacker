const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")
const webpackDevServerConfig = require("../webpackDevServerConfig")
const { runningWebpackDevServer } = require("../env")

const baseDevConfig = {
  mode: "development",
  devtool: "cheap-module-source-map"
}

const webpackDevConfig = () => ({
  ...baseDevConfig,
  ...(runningWebpackDevServer && { devServer: webpackDevServerConfig() })
})

const rspackDevConfig = () => ({
  ...baseDevConfig,
  devServer: {
    ...webpackDevServerConfig(),
    devMiddleware: {
      writeToDisk: (filePath) => !filePath.includes(".hot-update.")
    }
  }
})

const bundlerConfig =
  config.bundler === "rspack" ? rspackDevConfig() : webpackDevConfig()

module.exports = merge(baseConfig, bundlerConfig)
