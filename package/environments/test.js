const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")

const rspackTestConfig = {
  mode: "development",
  devtool: "cheap-module-source-map",
  // Disable file watching in test mode
  watchOptions: {
    ignored: /node_modules/
  }
}

const bundlerConfig =
  config.bundler === "rspack" ? rspackTestConfig : baseConfig

module.exports = merge(baseConfig, bundlerConfig)
