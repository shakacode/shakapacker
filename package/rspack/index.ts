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
let _rulesLoaded = false

const getRules = (): RuleSetRule[] => {
  if (!_rulesLoaded) {
    _rules = require(rulesPath) as RuleSetRule[]
    _rulesLoaded = true
  }

  return _rules as RuleSetRule[]
}

let _baseConfig: RspackConfigWithDevServer | undefined
let _baseConfigLoaded = false

const getBaseConfig = (): RspackConfigWithDevServer => {
  if (!_baseConfigLoaded) {
    _baseConfig = require("../environments/base") as RspackConfigWithDevServer
    _baseConfigLoaded = true
  }

  return _baseConfig as RspackConfigWithDevServer
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

// baseConfig and rules are installed below as lazy getters via
// Object.defineProperty. These ambient declarations exist only to shape the
// generated .d.ts: they advertise baseConfig/rules on the named-export surface
// with their real types, without forcing either module to load eagerly. Being
// ambient (`declare const`), they emit no runtime binding of their own.
//
// Mechanism: with module: commonjs (set in tsconfig.json, where a note on the
// "module" setting points back here), tsc initializes every named export to
// `void 0` at the top of the emitted module as a configurable data property.
// Installing an accessor via Object.defineProperty(exports, ...) below replaces
// that placeholder AND removes the export from Node's static CommonJS
// named-export detection (cjs-module-lexer) — which is why a native ESM
// `import { baseConfig } from "shakapacker/rspack"` throws "Named export not
// found" (a documented breaking change; see CHANGELOG). ESM consumers must use
// the default import or require(). The defineProperty calls succeed because the
// placeholder is configurable; a build target that emitted non-configurable
// export bindings would make them throw at load, and the guard after them fails
// loudly in the unlikely event a getter is otherwise not installed.
//
// TODO(#641): Once the module/export strategy is resolved, consider switching to
// the same local-object pattern used in package/index.ts (assemble the exports
// object, then install the getters on it) to remove this reliance on
// TypeScript's internal CommonJS emit behaviour.
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
  set(value: RuleSetRule[] | undefined) {
    // Assigning `undefined` resets to lazy loading rather than caching a
    // permanently-undefined value the getter would then return silently.
    _rules = value
    _rulesLoaded = value !== undefined
  }
})

Object.defineProperty(exports, "baseConfig", {
  configurable: true,
  enumerable: true,
  get: getBaseConfig,
  // Direct assignment (`require("shakapacker/rspack").baseConfig = custom`) runs
  // this setter and overrides the value read back from `baseConfig`. It changes
  // `generateRspackConfig` output ONLY in the fallback case where no
  // `environments/<NODE_ENV>.js` file exists, since that is the sole branch that
  // calls `getBaseConfig()`. Normal NODE_ENV builds load `environments/<env>.js`
  // (which `require("../environments/base")` directly), so the override does not
  // affect them.
  set(value: RspackConfigWithDevServer | undefined) {
    _baseConfig = value
    _baseConfigLoaded = value !== undefined
  }
})

// Fail loudly if the lazy getters were not installed (e.g. a future build target
// emits non-overridable export bindings), rather than silently shipping eager or
// missing baseConfig/rules exports.
;(["rules", "baseConfig"] as const).forEach((key) => {
  if (
    typeof Object.getOwnPropertyDescriptor(exports, key)?.get !== "function"
  ) {
    throw new Error(
      `[shakapacker] Failed to install the lazy '${key}' getter on shakapacker/rspack. ` +
        "This indicates the build emitted a non-configurable export binding for it. " +
        "See package/rspack/index.js."
    )
  }
})
