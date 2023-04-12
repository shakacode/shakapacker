const { merge } = require('webpack-merge')

const baseConfig = require('./base')
const devServerConfig = require('../dev_server')
const { runningWebpackDevServer } = require('../env')

let devConfig = {
  mode: 'development',
  devtool: 'cheap-module-source-map'
}

if (runningWebpackDevServer) {
  devConfig = merge(devConfig, {
    stats: {
      colors: true,
      entrypoints: false,
      errorDetails: true,
      modules: false,
      moduleTrace: false
    },
    devServer: devServerConfig
  })
}

module.exports = merge(baseConfig, devConfig)
