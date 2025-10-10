/**
 * Test environment configuration for webpack and rspack bundlers
 * @module environments/test
 */

import type { Configuration as WebpackConfiguration } from "webpack"
import { merge } from "webpack-merge"
import config from "../config"
import baseConfig from "./base"

interface TestConfig {
  mode: "development" | "production" | "none"
  devtool: string | false
  watchOptions?: {
    ignored: RegExp
  }
}

/**
 * Shared test configuration for both webpack and rspack
 * Ensures consistent test behavior across bundlers
 */
const sharedTestConfig: TestConfig = {
  mode: "development",
  devtool: "cheap-module-source-map",
  // Disable file watching in test mode
  watchOptions: {
    ignored: /node_modules/
  }
}

/**
 * Generate rspack-specific test configuration
 * @returns Rspack configuration optimized for testing
 */
const rspackTestConfig = (): TestConfig => ({
  ...sharedTestConfig
  // Add any rspack-specific overrides here if needed
})

/**
 * Generate webpack-specific test configuration
 * @returns Webpack configuration for testing with same settings as rspack
 */
const webpackTestConfig = (): Partial<WebpackConfiguration> => ({
  ...sharedTestConfig
  // Add any webpack-specific overrides here if needed
})

const bundlerConfig =
  config.assets_bundler === "rspack" ? rspackTestConfig() : webpackTestConfig()

export default merge(baseConfig, bundlerConfig)
