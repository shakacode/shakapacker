/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

import { resolve } from "path"
import { existsSync } from "fs"
// @ts-expect-error: webpack is an optional peer dependency (using type-only import)
import type { Configuration } from "webpack"

import webpackMerge from "webpack-merge"
import config from "./config"
import baseConfig from "./environments/base"
import devServer from "./dev_server"
import env from "./env"
import { moduleExists, canProcess } from "./utils/helpers"
import inliningCss from "./utils/inliningCss"

const rulesPath = resolve(__dirname, "rules", `${config.assets_bundler}.js`)
// eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
const rules = require(rulesPath) as unknown

const generateWebpackConfig = (
  extraConfig: Configuration = {},
  ...extraArgs: unknown[]
): Configuration => {
  if (extraArgs.length > 0) {
    throw new Error(
      `Invalid usage: generateWebpackConfig() accepts only one configuration object.\n\n` +
        `You passed ${extraArgs.length + 1} arguments. Only one extra config may be passed here - use webpack-merge to merge configs before passing them to Shakapacker.\n\n` +
        `Example:\n` +
        `  import { merge } from "webpack-merge"\n` +
        `  const mergedConfig = merge(config1, config2, config3)\n` +
        `  const finalConfig = generateWebpackConfig(mergedConfig)\n\n` +
        `Or if using ES6:\n` +
        `  import { merge } from 'webpack-merge'\n` +
        `  const finalConfig = generateWebpackConfig(merge(config1, config2))`
    )
  }

  const { nodeEnv } = env
  const path = resolve(__dirname, "environments", `${nodeEnv}.js`)
  const environmentConfig = existsSync(path) ? require(path) : baseConfig

  return webpackMerge.merge({}, environmentConfig, extraConfig)
}

export default {
  config, // shakapacker.yml
  devServer,
  generateWebpackConfig,
  baseConfig,
  env,
  rules,
  moduleExists,
  canProcess,
  inliningCss,
  ...webpackMerge
}
