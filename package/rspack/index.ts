/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

// Mixed require/import syntax:
// - Using require() for compiled JS modules that may not have proper ES module exports
// - Using import for type-only imports and Node.js built-in modules
const webpackMerge = require("webpack-merge")
import { resolve } from "path"
import { existsSync } from "fs"
import type { RspackConfigWithDevServer } from "../environments/types"
const config = require("../config")
const baseConfig = require("../environments/base")
const devServer = require("../dev_server")
const env = require("../env")
const { moduleExists, canProcess } = require("../utils/helpers")
const inliningCss = require("../utils/inliningCss")
const { getPlugins } = require("../plugins/rspack")
const { getOptimization } = require("../optimization/rspack")
const { validateRspackDependencies } = require("../utils/validateDependencies")

const rulesPath = resolve(__dirname, "../rules", "rspack.js")
const rules = require(rulesPath)

const generateRspackConfig = (extraConfig: RspackConfigWithDevServer = {}, ...extraArgs: unknown[]): RspackConfigWithDevServer => {
  // Validate required dependencies first
  validateRspackDependencies()
  if (extraArgs.length > 0) {
    throw new Error(
      "Only one extra config may be passed here - use webpack-merge to merge configs before passing them to Shakapacker"
    )
  }

  const { nodeEnv } = env
  const path = resolve(__dirname, "../environments", `${nodeEnv}.js`)
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const environmentConfig = existsSync(path) ? require(path) : baseConfig

  // Create base rspack config
  const rspackConfig: RspackConfigWithDevServer = {
    ...environmentConfig,
    module: {
      rules
    },
    plugins: getPlugins(),
    optimization: getOptimization()
  }

  return webpackMerge.merge({}, rspackConfig, extraConfig)
}

export {
  config, // shakapacker.yml
  devServer,
  generateRspackConfig,
  baseConfig,
  env,
  rules,
  moduleExists,
  canProcess,
  inliningCss
}

export * from "webpack-merge"
