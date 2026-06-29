/* eslint import/no-dynamic-require: 0 */

// Mixed require/import syntax:
// - Using require() for compiled JS modules that may not have proper ES module exports
// - Using import for type-only imports and Node.js built-in modules
import { resolve } from "path"
import { existsSync } from "fs"
// RuleSetRule is intentionally imported from "webpack": Shakapacker generates a
// single shared rule set (../rules/rspack.js) consumed by both bundlers, and
// rspack's rule shape is compatible with webpack's. Using the webpack type keeps
// the `rules` export type identical across the webpack and rspack entry points.
import type { RuleSetRule } from "webpack"
import type { RspackConfigWithDevServer } from "../environments/types"
import type { Config } from "../types"

const webpackMerge = require("webpack-merge") as typeof import("webpack-merge")
const config = require("../config") as Config
const devServer = require("../dev_server")
const env = require("../env")
const { moduleExists, canProcess } = require("../utils/helpers")
const createLazyExport =
  require("../utils/createLazyExport") as typeof import("../utils/createLazyExport")
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

const lazyRules = createLazyExport(() => require(rulesPath) as RuleSetRule[])
const lazyBaseConfig = createLazyExport(
  () => require("../environments/base") as RspackConfigWithDevServer
)

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

  const environmentConfig = existsSync(path)
    ? require(path)
    : lazyBaseConfig.get()

  return webpackMerge.merge({}, environmentConfig, extraConfig)
}

// baseConfig and rules are installed below as lazy getters via
// Object.defineProperty. These exported ambient declarations exist only to shape
// the generated .d.ts: they advertise baseConfig/rules on the TypeScript named
// export surface with their real types, without forcing either module to load
// eagerly and without emitting `exports.baseConfig = void 0` /
// `exports.rules = void 0` runtime placeholders. Keeping those placeholders out
// of the compiled CommonJS output is what makes Node's native ESM
// cjs-module-lexer reject named imports for the lazy values. ESM consumers must
// use the default import or require() for baseConfig/rules. The compiled-output
// contract is locked in by test/package/indexTypes.test.js.
export declare const baseConfig: RspackConfigWithDevServer
export declare const rules: RuleSetRule[]

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
  getProvidePlugin
}

// Override semantics (assignment override, defineProperty bypass) are
// documented on createLazyExport. A `require("shakapacker/rspack").baseConfig =
// custom` override changes `generateRspackConfig` output ONLY in the fallback
// case where no `environments/<NODE_ENV>.js` file exists, since that is the
// sole branch that reads the lazy value. Normal NODE_ENV builds load
// `environments/<env>.js` (which `require("../environments/base")` directly),
// so the override does not affect them.
Object.defineProperty(exports, "rules", lazyRules.descriptor)
Object.defineProperty(exports, "baseConfig", lazyBaseConfig.descriptor)
