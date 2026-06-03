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
    _rules = require(rulesPath) as RuleSetRule[]
  }

  return _rules
}

let _baseConfig: RspackConfigWithDevServer | undefined

const getBaseConfig = (): RspackConfigWithDevServer => {
  if (_baseConfig === undefined) {
    _baseConfig = require("../environments/base") as RspackConfigWithDevServer
  }

  return _baseConfig
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

// baseConfig and rules are installed below as lazy getters. These ambient
// declarations keep the generated .d.ts named export surface aligned with the
// runtime descriptors without forcing either module to load eagerly.
//
// Mechanism: with module: commonjs, TypeScript emits export placeholder
// assignments as configurable data properties that the Object.defineProperty
// calls below can replace with accessor descriptors. If this file is ever
// compiled to a format that emits non-configurable export descriptors, the lazy
// descriptor override will fail at module load time.
//
// This also relies on the placeholder assignments and the Object.defineProperty
// calls running in source order at module load: a bundler or minifier that
// hoists or reorders top-level statements could install the getter before the
// placeholder assignment and silently break the override. This file is not run
// through a bundler in practice, so this is a maintenance note rather than a
// live risk.
declare const baseConfig: RspackConfigWithDevServer
declare const rules: RuleSetRule[]

// Re-export webpack-merge utilities for backward compatibility
export {
  merge,
  mergeWithCustomize,
  mergeWithRules,
  unique
} from "webpack-merge"

export {
  config, // shakapacker.yml
  devServer,
  generateRspackConfig,
  baseConfig,
  env,
  rules,
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
  getProvidePlugin
}

Object.defineProperty(exports, "rules", {
  configurable: true,
  enumerable: true,
  get: getRules,
  set() {
    throw new TypeError(
      "shakapacker/rspack rules is read-only. Use Object.defineProperty(require('shakapacker/rspack'), 'rules', { value, writable: true, configurable: true }) to override it."
    )
  }
})

Object.defineProperty(exports, "baseConfig", {
  configurable: true,
  enumerable: true,
  get: getBaseConfig,
  set() {
    throw new TypeError(
      "shakapacker/rspack baseConfig is read-only. Use Object.defineProperty(require('shakapacker/rspack'), 'baseConfig', { value, writable: true, configurable: true }) to override it."
    )
  }
})
