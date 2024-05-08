const { merge } = require("webpack-merge")

const baseConfig = require("./base")
const webpackDevServerConfig = require("../webpackDevServerConfig")
const { runningWebpackDevServer } = require("../env")

const devConfig = {
  mode: "development",
  devtool: "cheap-module-source-map",
  ...(runningWebpackDevServer && { devServer: webpackDevServerConfig() })
}

module.exports = merge(baseConfig, devConfig)
