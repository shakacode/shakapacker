/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
/* eslint @typescript-eslint/no-require-imports: 0 */

import * as webpackMerge from "webpack-merge"
import { resolve } from "path"
import { existsSync } from "fs"
// @ts-ignore: webpack is an optional peer dependency (using type-only import)
import type { Configuration } from "webpack"
import config from "./config"
import baseConfig from "./environments/base"
import devServer from "./dev_server"
import { moduleExists, canProcess } from "./utils/helpers"
import inliningCss from "./utils/inliningCss"

// eslint-disable-next-line @typescript-eslint/no-require-imports
const env = require("./env")

const rulesPath = resolve(__dirname, "rules", `${config.assets_bundler}.js`)
const rules = require(rulesPath)

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
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const environmentConfig = existsSync(path) ? require(path) : baseConfig

  return webpackMerge.merge({}, environmentConfig, extraConfig)
}

export {
  config, // shakapacker.yml
  devServer,
  generateWebpackConfig,
  baseConfig,
  env,
  rules,
  moduleExists,
  canProcess,
  inliningCss
}

// Re-export webpack-merge utilities
export * from "webpack-merge"
