const { merge } = require("webpack-merge")

const baseConfig = require("./base")
const devServerConfig = require("../../webpackDevServerConfig") 
const { runningWebpackDevServer } = require("../../env")

const devConfig = {
  mode: "development",
  devtool: "cheap-module-source-map",
  ...(runningWebpackDevServer && { devServer: devServerConfig() })
}

module.exports = merge(baseConfig, devConfig)