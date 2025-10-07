/**
 * Development environment configuration for webpack and rspack bundlers
 * @module environments/development
 */

import { merge } from "webpack-merge"
import type {
  WebpackConfigWithDevServer,
  RspackConfigWithDevServer,
  _ReactRefreshWebpackPlugin,
  _ReactRefreshRspackPlugin
} from "./types"

import { runningWebpackDevServer } from "../env"
import { moduleExists } from "../utils/helpers"

const config = require("../config")
const baseConfig = require("./base")
const webpackDevServerConfig = require("../webpackDevServerConfig")

/**
 * Base development configuration shared between webpack and rspack
 */
const baseDevConfig = {
  mode: "development" as const,
  devtool: "cheap-module-source-map" as const
}

/**
 * Generate webpack-specific development configuration
 * @returns Webpack configuration with dev server settings
 */
const webpackDevConfig = (): WebpackConfigWithDevServer => {
  const webpackConfig: WebpackConfigWithDevServer = {
    ...baseDevConfig,
    ...(runningWebpackDevServer && { devServer: webpackDevServerConfig() })
  }

  const devServerConfig = webpackDevServerConfig()
  if (
    runningWebpackDevServer &&
    devServerConfig.hot &&
    moduleExists("@pmmmwh/react-refresh-webpack-plugin")
  ) {
    // eslint-disable-next-line global-require
    import _ReactRefreshWebpackPlugin from "@pmmmwh/react-refresh-webpack-plugin"

    webpackConfig.plugins = [
      ...(webpackConfig.plugins || []),
      new _ReactRefreshWebpackPlugin()
    ]
  }

  return webpackConfig
}

/**
 * Generate rspack-specific development configuration
 * @returns Rspack configuration with dev server settings
 */
const rspackDevConfig = (): RspackConfigWithDevServer => {
  const devServerConfig = webpackDevServerConfig()
  const rspackConfig: RspackConfigWithDevServer = {
    ...baseDevConfig,
    devServer: {
      ...devServerConfig,
      devMiddleware: {
        ...(devServerConfig.devMiddleware || {}),
        writeToDisk: (filePath: string) => !filePath.includes(".hot-update.")
      }
    }
  }

  if (
    runningWebpackDevServer &&
    devServerConfig.hot &&
    moduleExists("@rspack/plugin-react-refresh")
  ) {
    // eslint-disable-next-line global-require
    import ReactRefreshPlugin from "@rspack/plugin-react-refresh"

    rspackConfig.plugins = [
      ...(rspackConfig.plugins || []),
      new ReactRefreshPlugin()
    ]
  }

  return rspackConfig
}

const bundlerConfig =
  config.assets_bundler === "rspack" ? rspackDevConfig() : webpackDevConfig()

module.exports = merge(baseConfig, bundlerConfig)
