const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")

const rspackTestConfig = () => ({
  mode: "development",
  devtool: "cheap-module-source-map",
  // Disable file watching in test mode
  watchOptions: {
    ignored: /node_modules/
  }
})

const webpackTestConfig = () => ({})

const bundlerConfig =
  config.assets_bundler === "rspack" ? rspackTestConfig() : webpackTestConfig()

module.exports = merge(baseConfig, bundlerConfig)
