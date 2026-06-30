/**
 * Development environment configuration for webpack and rspack bundlers
 * @module environments/development
 */

import type { RuleSetUseItem } from "webpack"
import type {
  WebpackConfigWithDevServer,
  RspackConfigWithDevServer
} from "./types"
import type { Config } from "../types"

const { merge } = require("webpack-merge")
const config = require("../config") as Config
const baseConfig = require("./base")
const webpackDevServerConfig = require("../webpackDevServerConfig")
const { runningWebpackDevServer } = require("../env")
const { moduleExists } = require("../utils/helpers")

type SwcLoaderUse = {
  loader?: string
  options?: {
    jsc?: {
      transform?: {
        react?: {
          development?: boolean
          refresh?: boolean
        }
      }
    }
  }
}

type RspackDevConfigResult = {
  config: RspackConfigWithDevServer
  reactRefreshEnabled: boolean
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
const rspackDevConfig = (): RspackDevConfigResult => {
  const devServerConfig = webpackDevServerConfig()
  let reactRefreshEnabled = false
  const rspackConfig: RspackConfigWithDevServer = {
    ...baseDevConfig,
    lazyCompilation: false,
    ...(runningWebpackDevServer && {
      devServer: {
        ...devServerConfig,
        devMiddleware: {
          ...(devServerConfig.devMiddleware || {}),
          writeToDisk: (filePath: string) => !filePath.includes(".hot-update.")
        }
      }
    })
  }

  if (
    runningWebpackDevServer &&
    devServerConfig.hot &&
    moduleExists("@rspack/plugin-react-refresh")
  ) {
    const reactRefreshPlugin = require("@rspack/plugin-react-refresh")
    const ReactRefreshRspackPlugin =
      typeof reactRefreshPlugin.ReactRefreshRspackPlugin === "function"
        ? reactRefreshPlugin.ReactRefreshRspackPlugin
        : null
    if (typeof ReactRefreshRspackPlugin !== "function") {
      console.warn(
        "[SHAKAPACKER WARNING] Could not resolve a constructor from @rspack/plugin-react-refresh; React Refresh will be skipped in development."
      )
    } else {
      reactRefreshEnabled = true
      rspackConfig.plugins = [
        ...(rspackConfig.plugins || []),
        new ReactRefreshRspackPlugin()
      ]
    }
  }

  return { config: rspackConfig, reactRefreshEnabled }
}

const enableRspackReactRefreshTransform = (
  environmentConfig: RspackConfigWithDevServer
) => {
  const enableLoaderTransform = (loaderConfig: SwcLoaderUse) => {
    if (loaderConfig.loader !== "builtin:swc-loader") return

    /* eslint-disable no-param-reassign -- this helper mutates the merged webpack/rspack config in place */
    loaderConfig.options ||= {}
    loaderConfig.options.jsc ||= {}
    loaderConfig.options.jsc.transform ||= {}
    loaderConfig.options.jsc.transform.react ||= {}
    loaderConfig.options.jsc.transform.react.development = true
    loaderConfig.options.jsc.transform.react.refresh = true
    /* eslint-enable no-param-reassign */
  }

  const visitRules = (rules: unknown[]) => {
    rules.forEach((rule) => {
      if (!rule || typeof rule !== "object") return

      const ruleWithLoaders = rule as SwcLoaderUse & {
        oneOf?: unknown[]
        rules?: unknown[]
        use?: RuleSetUseItem | RuleSetUseItem[]
      }

      if (Array.isArray(ruleWithLoaders.oneOf))
        visitRules(ruleWithLoaders.oneOf)
      if (Array.isArray(ruleWithLoaders.rules))
        visitRules(ruleWithLoaders.rules)

      enableLoaderTransform(ruleWithLoaders)

      const loaders = Array.isArray(ruleWithLoaders.use)
        ? ruleWithLoaders.use
        : [ruleWithLoaders.use]

      loaders.forEach((loader) => {
        if (!loader || typeof loader !== "object" || !("loader" in loader))
          return

        enableLoaderTransform(loader as SwcLoaderUse)
      })
    })
  }

  const rules = environmentConfig.module?.rules
  if (Array.isArray(rules)) visitRules(rules)
}

const { config: bundlerConfig, reactRefreshEnabled } =
  config.assets_bundler === "rspack"
    ? rspackDevConfig()
    : { config: webpackDevConfig(), reactRefreshEnabled: false }

const environmentConfig = merge(baseConfig, bundlerConfig)

if (reactRefreshEnabled) {
  enableRspackReactRefreshTransform(environmentConfig)
}

module.exports = environmentConfig
