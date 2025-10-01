/**
 * Development environment configuration for webpack and rspack bundlers
 * @module environments/development
 */

const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")
const webpackDevServerConfig = require("../webpackDevServerConfig")
const { runningWebpackDevServer } = require("../env")
const { moduleExists } = require("../utils/helpers")
import type { Configuration as WebpackConfiguration, WebpackPluginInstance } from "webpack"
import type { Configuration as DevServerConfiguration } from "webpack-dev-server"

interface WebpackConfigWithDevServer extends WebpackConfiguration {
  devServer?: DevServerConfiguration
  plugins?: WebpackPluginInstance[]
}

interface RspackDevServerConfig {
  [key: string]: unknown
  devMiddleware?: {
    writeToDisk?: boolean | ((filePath: string) => boolean)
    [key: string]: unknown
  }
}

interface RspackConfigWithDevServer {
  mode?: "development" | "production" | "none"
  devtool?: string | false
  devServer?: RspackDevServerConfig
  plugins?: Array<{ new(...args: any[]): any }>
}

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
        ...devServerConfig.devMiddleware,
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

module.exports = merge(baseConfig, bundlerConfig)
