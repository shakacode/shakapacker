const { merge } = require("webpack-merge")

const baseConfig = require("./base")

const testConfig = {
  mode: "development",
  devtool: "cheap-module-source-map",
  // Disable file watching in test mode
  watchOptions: {
    ignored: /node_modules/
  }
}

module.exports = merge(baseConfig, testConfig)
