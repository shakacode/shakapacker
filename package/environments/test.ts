/**
 * Test environment configuration for webpack and rspack bundlers
 * @module environments/test
 */

const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")
import type { Configuration as WebpackConfiguration } from "webpack"

interface RspackTestConfig {
  mode: "development" | "production" | "none"
  devtool: string | false
  watchOptions?: {
    ignored: RegExp
  }
}

/**
 * Generate rspack-specific test configuration
 * @returns Rspack configuration optimized for testing
 */
const rspackTestConfig = (): RspackTestConfig => ({
  mode: "development",
  devtool: "cheap-module-source-map",
  // Disable file watching in test mode
  watchOptions: {
    ignored: /node_modules/
  }
})

/**
 * Generate webpack-specific test configuration
 * @returns Webpack configuration for testing (uses default settings)
 */
const webpackTestConfig = (): Partial<WebpackConfiguration> => ({})

const bundlerConfig =
  config.assets_bundler === "rspack" ? rspackTestConfig() : webpackTestConfig()

module.exports = merge(baseConfig, bundlerConfig)
