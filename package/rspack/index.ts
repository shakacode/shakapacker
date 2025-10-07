/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

// Mixed require/import syntax:
// - Using require() for compiled JS modules that may not have proper ES module exports
// - Using import for type-only imports and Node.js built-in modules
import { resolve } from "path"
import { existsSync } from "fs"
import webpackMerge from "webpack-merge"
import type { RspackConfigWithDevServer } from "../environments/types"

import { moduleExists, canProcess } from "../utils/helpers"
import { getPlugins } from "../plugins/rspack"
import { getOptimization } from "../optimization/rspack"
import { validateRspackDependencies } from "../utils/validateDependencies"

// eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
const config = require("../config") as unknown
// eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
const baseConfig = require("../environments/base") as unknown
// eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
const devServer = require("../dev_server") as unknown
// eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
const env = require("../env") as unknown

// eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
const inliningCss = require("../utils/inliningCss") as unknown

const rulesPath = resolve(__dirname, "../rules", "rspack.js")
// eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
const rules = require(rulesPath) as unknown

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
  inliningCss
}
