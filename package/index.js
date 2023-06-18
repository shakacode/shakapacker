/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const webpackMerge = require('webpack-merge')
const { resolve } = require('path')
const { existsSync } = require('fs')
const baseConfig = require('./environments/base')
const rules = require('./rules')
const config = require('./config')
const devServer = require('./dev_server')
const env = require('./env')
const { moduleExists, canProcess } = require('./utils/helpers')
const inliningCss = require('./utils/inliningCss')

const globalMutableWebpackConfig = () => {
  const { nodeEnv } = env
  const path = resolve(__dirname, 'environments', `${nodeEnv}.js`)
  const environmentConfig = existsSync(path) ? require(path) : baseConfig
  return environmentConfig
}

const generateWebpackConfig = () => {
  const environmentConfig = globalMutableWebpackConfig()
  const immutable = webpackMerge.merge({}, environmentConfig)
  return immutable
}

module.exports = {
  config, // shakapacker.yml
  devServer,
  generateWebpackConfig,
  globalMutableWebpackConfig: globalMutableWebpackConfig(),
  webpackConfig: globalMutableWebpackConfig(),
  baseConfig,
  env,
  rules,
  moduleExists,
  canProcess,
  inliningCss,
  ...webpackMerge
}
