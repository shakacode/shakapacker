/* eslint import/no-dynamic-require: 0 */

// Mixed require/import syntax:
// - Using require() for compiled JS modules that may not have proper ES module exports
// - Using import for type-only imports and Node.js built-in modules
import { resolve } from "path"
import { existsSync } from "fs"
import type { RuleSetRule } from "webpack"
import type { RspackConfigWithDevServer } from "../environments/types"
import type { Config } from "../types"

const webpackMerge = require("webpack-merge")
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

// Declaration placeholders keep TypeScript's named exports while runtime values
// are installed as lazy getters below. TypeScript's CommonJS emit writes these
// `export { baseConfig, rules }` lines as plain `exports.baseConfig = baseConfig`
// assignments (configurable: true by default), so the subsequent
// Object.defineProperty calls can safely replace them with getters. If TypeScript
// ever switches to non-configurable Object.defineProperty for named exports,
// the override will throw and test/package/rspack/indexSideEffects.test.js will
// catch the regression at module load.
const baseConfig = undefined as unknown as RspackConfigWithDevServer // replaced below by lazy getter
const rules = undefined as unknown as RuleSetRule[] // replaced below by lazy getter

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

// `baseConfig` is exposed via a lazy getter so requiring this module does not
// load `environments/base` (and its transitive plugin/manifest side effects)
// until a caller actually reads the property. Aliasing `module.exports` keeps
// the target obvious and avoids relying on the implicit `exports === module.exports`
// identity that TypeScript does not surface.
const rspackExports = module.exports

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
