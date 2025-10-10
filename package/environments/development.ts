/**
 * Development environment configuration for webpack and rspack bundlers
 * @module environments/development
 */

import { merge } from "webpack-merge"
import type {
  WebpackConfigWithDevServer,
  RspackConfigWithDevServer,
  ReactRefreshWebpackPlugin,
  ReactRefreshRspackPlugin
} from "./types"
import config from "../config"
import baseConfig from "./base"
import webpackDevServerConfig from "../webpackDevServerConfig"
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runningWebpackDevServer } = require("../env")
import { moduleExists } from "../utils/helpers"

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
    // eslint-disable-next-line global-require, @typescript-eslint/no-require-imports
    const ReactRefreshWebpackPlugin = require("@pmmmwh/react-refresh-webpack-plugin")
    webpackConfig.plugins = [
      ...(webpackConfig.plugins || []),
      new ReactRefreshWebpackPlugin()
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
    // eslint-disable-next-line global-require, @typescript-eslint/no-require-imports
    const ReactRefreshPlugin = require("@rspack/plugin-react-refresh")
    rspackConfig.plugins = [
      ...(rspackConfig.plugins || []),
      new ReactRefreshPlugin()
    ]
  }

  return rspackConfig
}

const bundlerConfig =
  config.assets_bundler === "rspack" ? rspackDevConfig() : webpackDevConfig()

export default merge(baseConfig, bundlerConfig)
