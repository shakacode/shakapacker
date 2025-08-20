const { merge } = require("webpack-merge")

const baseConfig = require("./base")
const devServerConfig = require("../../webpackDevServerConfig")

const devConfig = {
  mode: "development",
  devtool: "cheap-module-source-map",
  // Force writing assets to disk in development for Rails compatibility
  devServer: {
    ...devServerConfig(),
    devMiddleware: {
      writeToDisk: true
    }
  }
}

module.exports = merge(baseConfig, devConfig)
