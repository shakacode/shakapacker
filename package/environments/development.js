const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")
const webpackDevServerConfig = require("../webpackDevServerConfig")
const { runningWebpackDevServer } = require("../env")

const webpackDevConfig = () => ({
  mode: "development",
  devtool: "cheap-module-source-map",
  ...(runningWebpackDevServer && { devServer: webpackDevServerConfig() })
})

const rspackDevConfig = () => ({
  mode: "development",
  devtool: "cheap-module-source-map",
  // Force writing assets to disk in development for Rails compatibility
  devServer: {
    ...webpackDevServerConfig(),
    devMiddleware: {
      writeToDisk: true
    }
  }
})

const bundlerConfig =
  config.bundler === "rspack" ? rspackDevConfig() : webpackDevConfig()

module.exports = merge(baseConfig, bundlerConfig)
