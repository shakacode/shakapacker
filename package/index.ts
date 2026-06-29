/* eslint import/no-dynamic-require: 0 */

import * as webpackMerge from "webpack-merge"
import { resolve } from "path"
import { existsSync } from "fs"
import type { Configuration, RuleSetRule } from "webpack"
import config from "./config"
import devServer from "./dev_server"
import env from "./env"
import { moduleExists, canProcess } from "./utils/helpers"
import createLazyExport from "./utils/createLazyExport"
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

const lazyRules = createLazyExport(() => require(rulesPath) as RuleSetRule[])
const lazyBaseConfig = createLazyExport(
  () => require("./environments/base") as Configuration
)

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
  const environmentConfig = existsSync(path)
    ? require(path)
    : lazyBaseConfig.get()

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

// Preserve Node native-ESM named imports for the non-lazy CommonJS exports used
// by generated TypeScript configs. Do not add baseConfig/rules here: those stay
// accessor-only so importing them by name cannot eagerly load optional bundler
// dependencies.
exports.config = config
exports.devServer = devServer
exports.generateWebpackConfig = generateWebpackConfig
exports.env = env
exports.moduleExists = moduleExists
exports.canProcess = canProcess
exports.inliningCss = inliningCss
exports.isRspack = isRspack
exports.isWebpack = isWebpack
exports.getBundler = getBundler
exports.getCssExtractPlugin = getCssExtractPlugin
exports.getCssExtractPluginLoader = getCssExtractPluginLoader
exports.getDefinePlugin = getDefinePlugin
exports.getEnvironmentPlugin = getEnvironmentPlugin
exports.getProvidePlugin = getProvidePlugin
exports.merge = webpackMerge.merge
exports.mergeWithCustomize = webpackMerge.mergeWithCustomize
exports.mergeWithRules = webpackMerge.mergeWithRules
exports.unique = webpackMerge.unique

// Override semantics (assignment override, defineProperty bypass) are
// documented on createLazyExport. A `shakapacker.baseConfig = custom` override
// changes `generateWebpackConfig` output ONLY in the fallback case where no
// `environments/<NODE_ENV>.js` file exists, since that is the sole branch that
// reads the lazy value. Normal NODE_ENV builds load `environments/<env>.js`
// (which `require("./base")` directly), so the override does not affect them.
Object.defineProperty(shakapacker, "rules", lazyRules.descriptor)
Object.defineProperty(shakapacker, "baseConfig", lazyBaseConfig.descriptor)

export = shakapacker
