/* eslint import/no-dynamic-require: 0 */

import * as webpackMerge from "webpack-merge"
import { resolve } from "path"
import { existsSync } from "fs"
import type { Configuration, RuleSetRule } from "webpack"
import config from "./config"
import devServer from "./dev_server"
import env from "./env"
import { moduleExists, canProcess } from "./utils/helpers"
import inliningCss from "./utils/inliningCss"
import {
  isRspack,
  isWebpack,
  getBundler,
  getCssExtractPlugin,
  getCssExtractPluginLoader,
  getDefinePlugin,
  getEnvironmentPlugin,
  getProvidePlugin
} from "./utils/bundlerUtils"

const rulesPath = resolve(__dirname, "rules", `${config.assets_bundler}.js`)

let _rules: RuleSetRule[] | undefined

const getRules = (): RuleSetRule[] => {
  if (_rules === undefined) {
    _rules = require(rulesPath) as RuleSetRule[]
  }

  return _rules
}

let _baseConfig: Configuration | undefined

const getBaseConfig = (): Configuration => {
  if (_baseConfig === undefined) {
    _baseConfig = require("./environments/base") as Configuration
  }

  return _baseConfig
}

/**
 * Generate webpack configuration with optional custom config.
 *
 * @param extraConfig - Optional webpack configuration to merge with base config
 * @returns Final webpack configuration
 * @throws {Error} If more than one argument is provided
 */
const generateWebpackConfig = (
  extraConfig: Configuration = {},
  ...extraArgs: unknown[]
): Configuration => {
  if (extraArgs.length > 0) {
    throw new Error(
      `Invalid usage: generateWebpackConfig() accepts only one configuration object.\n\n` +
        `You passed ${extraArgs.length + 1} arguments. Only one extra config may be passed here - use webpack-merge to merge configs before passing them to Shakapacker.\n\n` +
        `Example:\n` +
        `  const { merge } = require('webpack-merge')\n` +
        `  const mergedConfig = merge(config1, config2, config3)\n` +
        `  const finalConfig = generateWebpackConfig(mergedConfig)\n\n` +
        `Or if using ES6:\n` +
        `  import { merge } from 'webpack-merge'\n` +
        `  const finalConfig = generateWebpackConfig(merge(config1, config2))`
    )
  }

  const { nodeEnv } = env
  const path = resolve(__dirname, "environments", `${nodeEnv}.js`)
  const environmentConfig = existsSync(path) ? require(path) : getBaseConfig()

  return webpackMerge.merge({}, environmentConfig, extraConfig)
}

/**
 * The Shakapacker module exports.
 * This object is exported via CommonJS `export =`.
 *
 * NOTE: This pattern is temporary and will be replaced with named exports
 * once issue #641 is resolved.
 */
const shakapacker = {
  /** Shakapacker configuration from shakapacker.yml */
  config,
  /** Development server configuration */
  devServer,
  /** Generate webpack configuration with optional custom config */
  generateWebpackConfig,
  /** Environment configuration (railsEnv, nodeEnv, etc.) */
  env,
  /** Check if a module exists in node_modules */
  moduleExists,
  /** Process a file if a specific loader is available */
  canProcess,
  /** Whether CSS should be inlined (dev server with HMR) */
  inliningCss,
  /** Whether the current bundler is Rspack */
  isRspack,
  /** Whether the current bundler is Webpack */
  isWebpack,
  /** Get the bundler module (webpack or @rspack/core) */
  getBundler,
  /** Get the CSS extraction plugin for the current bundler */
  getCssExtractPlugin,
  /** Get the CSS extraction plugin loader for the current bundler */
  getCssExtractPluginLoader,
  /** Get the DefinePlugin for the current bundler */
  getDefinePlugin,
  /** Get the EnvironmentPlugin for the current bundler */
  getEnvironmentPlugin,
  /** Get the ProvidePlugin for the current bundler */
  getProvidePlugin,
  /** webpack-merge functions (merge, mergeWithCustomize, mergeWithRules, unique) */
  ...webpackMerge
}

Object.defineProperty(shakapacker, "rules", {
  configurable: true,
  enumerable: true,
  get: getRules,
  set() {
    throw new TypeError(
      "shakapacker.rules is read-only. Use Object.defineProperty(shakapacker, 'rules', { value, writable: true, configurable: true }) to override it."
    )
  }
})

Object.defineProperty(shakapacker, "baseConfig", {
  configurable: true,
  enumerable: true,
  get: getBaseConfig,
  set() {
    throw new TypeError(
      "shakapacker.baseConfig is read-only. Use Object.defineProperty(shakapacker, 'baseConfig', { value, writable: true, configurable: true }) to override it."
    )
  }
})

export = shakapacker
