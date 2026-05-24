/* eslint import/no-dynamic-require: 0 */

// Mixed require/import syntax:
// - Using require() for compiled JS modules that may not have proper ES module exports
// - Using import for type-only imports and Node.js built-in modules
import { resolve } from "path"
import { existsSync } from "fs"
import type { RuleSetRule } from "webpack"
import type { RspackConfigWithDevServer } from "../environments/types"
import type { Config } from "../types"

const webpackMerge = require("webpack-merge") as typeof import("webpack-merge")
const config = require("../config") as Config
const devServer = require("../dev_server")
const env = require("../env")
const { moduleExists, canProcess } = require("../utils/helpers")
const inliningCss = require("../utils/inliningCss")
const {
  isRspack,
  isWebpack,
  getBundler,
  getCssExtractPlugin,
  getCssExtractPluginLoader,
  getDefinePlugin,
  getEnvironmentPlugin,
  getProvidePlugin
} = require("../utils/bundlerUtils")
const { validateRspackDependencies } = require("../utils/validateDependencies")

const rulesPath = resolve(__dirname, "../rules", "rspack.js")

let _rules: RuleSetRule[] | undefined

const getRules = (): RuleSetRule[] => {
  if (_rules === undefined) {
    _rules = require(rulesPath)
  }

  return _rules!
}

let _baseConfig: RspackConfigWithDevServer | undefined

const getBaseConfig = (): RspackConfigWithDevServer => {
  if (_baseConfig === undefined) {
    _baseConfig = require("../environments/base")
  }

  return _baseConfig!
}

const generateRspackConfig = (
  extraConfig: RspackConfigWithDevServer = {},
  ...extraArgs: unknown[]
): RspackConfigWithDevServer => {
  // Validate required dependencies first
  validateRspackDependencies()
  if (extraArgs.length > 0) {
    throw new Error(
      "Only one extra config may be passed here - use webpack-merge to merge configs before passing them to Shakapacker"
    )
  }

  const { nodeEnv } = env
  const path = resolve(__dirname, "../environments", `${nodeEnv}.js`)

  const environmentConfig = existsSync(path) ? require(path) : getBaseConfig()

  return webpackMerge.merge({}, environmentConfig, extraConfig)
}

type RspackExports = typeof webpackMerge & {
  config: typeof config
  devServer: typeof devServer
  generateRspackConfig: typeof generateRspackConfig
  readonly baseConfig: RspackConfigWithDevServer
  env: typeof env
  readonly rules: RuleSetRule[]
  moduleExists: typeof moduleExists
  canProcess: typeof canProcess
  inliningCss: typeof inliningCss
  isRspack: typeof isRspack
  isWebpack: typeof isWebpack
  getBundler: typeof getBundler
  getCssExtractPlugin: typeof getCssExtractPlugin
  getCssExtractPluginLoader: typeof getCssExtractPluginLoader
  getDefinePlugin: typeof getDefinePlugin
  getEnvironmentPlugin: typeof getEnvironmentPlugin
  getProvidePlugin: typeof getProvidePlugin
}

const rspackExports = {
  // shakapacker.yml
  config,
  devServer,
  generateRspackConfig,
  env,
  moduleExists,
  canProcess,
  inliningCss,
  isRspack,
  isWebpack,
  getBundler,
  getCssExtractPlugin,
  getCssExtractPluginLoader,
  getDefinePlugin,
  getEnvironmentPlugin,
  getProvidePlugin,
  // webpack-merge utilities for backward compatibility
  ...webpackMerge
} as RspackExports

Object.defineProperty(rspackExports, "rules", {
  configurable: true,
  enumerable: true,
  get: getRules,
  set() {
    throw new TypeError(
      "shakapacker/rspack rules is read-only. Use Object.defineProperty(require('shakapacker/rspack'), 'rules', { value, writable: true, configurable: true }) to override it."
    )
  }
})

Object.defineProperty(rspackExports, "baseConfig", {
  configurable: true,
  enumerable: true,
  get: getBaseConfig,
  set() {
    throw new TypeError(
      "shakapacker/rspack baseConfig is read-only. Use Object.defineProperty(require('shakapacker/rspack'), 'baseConfig', { value, writable: true, configurable: true }) to override it."
    )
  }
})

export = rspackExports
