/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const webpackMerge = require("webpack-merge")
const { resolve } = require("path")
const { existsSync } = require("fs")
const config = require("../config")
const baseConfig = require("../environments/base")

const rulesPath = resolve(__dirname, "../rules", "rspack.js")
const rules = require(rulesPath)
const devServer = require("../dev_server")
const env = require("../env")
const { moduleExists, canProcess } = require("../utils/helpers")
const inliningCss = require("../utils/inliningCss")
const { getPlugins } = require("../plugins/rspack")
const { getOptimization } = require("../optimization/rspack")

const generateRspackConfig = (extraConfig = {}, ...extraArgs) => {
  if (extraArgs.length > 0) {
    throw new Error(
      "Only one extra config may be passed here - use webpack-merge to merge configs before passing them to Shakapacker"
    )
  }

  const { nodeEnv } = env
  const path = resolve(__dirname, "../environments", `${nodeEnv}.js`)
  const environmentConfig = existsSync(path) ? require(path) : baseConfig

  // Create base rspack config
  const rspackConfig = {
    ...environmentConfig,
    module: {
      rules
    },
    plugins: getPlugins(),
    optimization: getOptimization()
  }

  return webpackMerge.merge({}, rspackConfig, extraConfig)
}

module.exports = {
  config, // shakapacker.yml
  devServer,
  generateRspackConfig,
  baseConfig,
  env,
  rules,
  moduleExists,
  canProcess,
  inliningCss,
  ...webpackMerge
}
