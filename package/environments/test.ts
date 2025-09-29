const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")
import type { Configuration as WebpackConfiguration } from "webpack"

interface RspackTestConfig {
  mode: string
  devtool: string | false | undefined
  watchOptions?: {
    ignored: RegExp
  }
}

const rspackTestConfig = (): RspackTestConfig => ({
  mode: "development",
  devtool: "cheap-module-source-map",
  // Disable file watching in test mode
  watchOptions: {
    ignored: /node_modules/
  }
})

const webpackTestConfig = (): Partial<WebpackConfiguration> => ({})

const bundlerConfig =
  config.assets_bundler === "rspack" ? rspackTestConfig() : webpackTestConfig()

module.exports = merge(baseConfig, bundlerConfig)
