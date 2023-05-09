const { merge } = require('webpack-merge')

const baseConfig = require('./base')
const shakapackerDevServerConfig = require('../dev_server')
const { runningWebpackDevServer } = require('../env')

const { outputPath: contentBase, publicPath } = require('../config')

const webpackSpecificKeysMapToCamelCase = {
  allowed_hosts: 'allowedHosts',
  magic_html: 'magicHtml',
  on_after_setup_middleware: 'onAfterSetupMiddleware',
  on_before_setup_middleware: 'onBeforeSetupMiddleware',
  on_listening: 'onListening',
  setup_exit_signals: 'setupExitSignals',
  setup_middlewares: 'setupMiddlewares',
  watch_files: 'watchFiles',
  web_socket_server: 'webSocketServer'
}

const webpackDevServerValidKeys = new Set([
  'allowedHosts',
  'bonjour',
  'client',
  'compress',
  'devMiddleware',
  'headers',
  'historyApiFallback',
  'host',
  'hot',
  'http2',
  'https',
  'ipc',
  'liveReload',
  'magicHtml',
  'onAfterSetupMiddleware',
  'onBeforeSetupMiddleware',
  'open',
  'port',
  'proxy',
  'server',
  'setupExitSignals',
  'setupMiddlewares',
  'static',
  'watchFiles',
  'webSocketServer'
])

let devConfig = {
  mode: 'development',
  devtool: 'cheap-module-source-map'
}

if (runningWebpackDevServer) {
  const liveReload = shakapackerDevServerConfig.live_reload !== undefined ? shakapackerDevServerConfig.live_reload : !shakapackerDevServerConfig.hmr

  const devServerConfig = {
    devMiddleware: {
      publicPath
    },
    liveReload,
    historyApiFallback: { disableDotRule: true },
    static: {
      publicPath: contentBase
    }
  }

  if (shakapackerDevServerConfig.static) {
    devServerConfig.static = { ...devServerConfig.static, ...shakapackerDevServerConfig.static }
  }

  if (shakapackerDevServerConfig.client) {
    devServerConfig.client = shakapackerDevServerConfig.client
  }

  // Copying all the entries by only converting webpack specific keys from
  // snake_case to camelCase. Any other entries are copied identically.
  Object.keys(shakapackerDevServerConfig).forEach((rubyKey) => {
    const webpackKey = webpackSpecificKeysMapToCamelCase[rubyKey] ? webpackSpecificKeysMapToCamelCase[rubyKey] : rubyKey
    if (webpackDevServerValidKeys.has(webpackKey)) {
      devServerConfig[webpackKey] = devServerConfig[webpackKey] || shakapackerDevServerConfig[rubyKey]
    }
  })

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
