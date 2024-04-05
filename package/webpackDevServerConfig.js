const shakapackerDevServerYamlConfig = require("./dev_server")
const snakeToCamelCase = require("./utils/snakeToCamelCase")
const { outputPath: contentBase, publicPath } = require("./config")

const webpackDevServerMappedKeys = new Set([
  // client, server, liveReload, devMiddleware are handled separately
  "allowedHosts",
  "bonjour",
  "compress",
  "headers",
  "historyApiFallback",
  "host",
  "hot",
  "http2",
  "https",
  "ipc",
  "magicHtml",
  "onAfterSetupMiddleware",
  "onBeforeSetupMiddleware",
  "open",
  "port",
  "proxy",
  "server",
  "setupExitSignals",
  "setupMiddlewares",
  "watchFiles",
  "webSocketServer"
])

function createDevServerConfig() {
  const devServerYamlConfig = { ...shakapackerDevServerYamlConfig }
  const liveReload =
    devServerYamlConfig.live_reload !== undefined
      ? devServerYamlConfig.live_reload
      : !devServerYamlConfig.hmr
  delete devServerYamlConfig.live_reload

  const config = {
    devMiddleware: {
      publicPath
    },
    liveReload,
    historyApiFallback: {
      disableDotRule: true
    },
    static: {
      publicPath: contentBase
    }
  }

  if (devServerYamlConfig.static) {
    config.static = { ...config.static, ...devServerYamlConfig.static }
    delete devServerYamlConfig.static
  }

  if (devServerYamlConfig.client) {
    config.client = devServerYamlConfig.client
    delete devServerYamlConfig.client
  }

  Object.keys(devServerYamlConfig).forEach((yamlKey) => {
    const camelYamlKey = snakeToCamelCase(yamlKey)
    if (webpackDevServerMappedKeys.has(camelYamlKey)) {
      config[camelYamlKey] = devServerYamlConfig[yamlKey]
    }
  })

  return config
}

module.exports = createDevServerConfig
