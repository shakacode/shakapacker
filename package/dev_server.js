const { isBoolean } = require('./utils/helpers')
const config = require('./config')
const { outputPath: contentBase, publicPath } = require('./config')
const { isDevelopment } = require('./env')

const fetchFromEnv = (key) => {
  const value = process.env[key]
  return isBoolean(value) ? JSON.parse(value) : value
}

let devServer = {}

if (isDevelopment) {
  const devServerFromConfigFile = config.dev_server

  if (devServerFromConfigFile) {
    const envPrefix = devServerFromConfigFile.env_prefix || 'SHAKAPACKER_DEV_SERVER'

    Object.keys(devServerFromConfigFile).forEach((key) => {
      const envValue = fetchFromEnv(`${envPrefix}_${key.toUpperCase()}`)
      if (envValue !== undefined) devServerFromConfigFile[key] = envValue
    })
  }

  const liveReload = devServerFromConfigFile.live_reload !== undefined ? devServerFromConfigFile.live_reload : !devServerFromConfigFile.hmr

  devServer = {
    devMiddleware: {
      publicPath
    },
    liveReload,
    historyApiFallback: { disableDotRule: true },
    static: {
      publicPath: contentBase
    }
  }

  if (devServerFromConfigFile.static) {
    devServer.static = { ...devServer.static, ...devServerFromConfigFile.static }
  }

  if (devServerFromConfigFile.client) {
    devServer.client = devServerFromConfigFile.client
  }

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

  // Copying all the entries by only converting webpack specific keys from
  // snake_case to camelCase. Any other entries are copied identically.
  Object.keys(devServerFromConfigFile).forEach((rubyKey) => {
    const webpackKey = webpackSpecificKeysMapToCamelCase[rubyKey] ? webpackSpecificKeysMapToCamelCase[rubyKey] : rubyKey
    devServer[webpackKey] = devServer[webpackKey] || devServerFromConfigFile[rubyKey]
  })
}

module.exports = devServer
