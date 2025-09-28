/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const webpackMerge = require("webpack-merge")
import { resolve } from "path"
import { existsSync } from "fs"
import { Configuration } from "webpack"
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
      "Only one extra config may be passed here - use webpack-merge to merge configs before passing them to Shakapacker"
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