/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const webpackMerge = require("webpack-merge")
import { resolve } from "path"
import { existsSync } from "fs"
// @ts-ignore: webpack is an optional peer dependency (using type-only import)
import type { Configuration } from "webpack"
const config = require("./config")
const baseConfig = require("./environments/base")
const devServer = require("./dev_server")
const env = require("./env")
const { moduleExists, canProcess } = require("./utils/helpers")
const inliningCss = require("./utils/inliningCss")

const rulesPath = resolve(__dirname, "rules", `${config.assets_bundler}.js`)
const rules = require(rulesPath)

const generateWebpackConfig = (extraConfig: Configuration = {}, ...extraArgs: any[]): Configuration => {
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
  const environmentConfig = existsSync(path) ? require(path) : baseConfig

  return webpackMerge.merge({}, environmentConfig, extraConfig)
}

export = {
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
