import { DevServerConfig } from "./types"
import snakeToCamelCase from "./utils/snakeToCamelCase"
import shakapackerDevServerYamlConfig from "./dev_server"
import config from "./config"

const { outputPath: contentBase, publicPath } = config

interface WebpackDevServerConfig {
  devMiddleware?: {
    publicPath?: string
  }
  hot?: boolean | string
  liveReload?: boolean
  historyApiFallback?:
    | boolean
    | {
        disableDotRule?: boolean
      }
  static?: {
    publicPath?: string
    [key: string]: unknown
  }
  client?: Record<string, unknown>
  allowedHosts?: "all" | "auto" | (string & {}) | string[]
  bonjour?: boolean | Record<string, unknown>
  compress?: boolean
  headers?: Record<string, unknown> | (() => Record<string, unknown>)
  host?: "local-ip" | "local-ipv4" | "local-ipv6" | (string & {})
  http2?: boolean
  https?: boolean | Record<string, unknown>
  ipc?: boolean | string
  magicHtml?: boolean
  onAfterSetupMiddleware?: (devServer: unknown) => void
  onBeforeSetupMiddleware?: (devServer: unknown) => void
  open?:
    | boolean
    | string
    | string[]
    | Record<string, unknown>
    | Record<string, unknown>[]
  port?: "auto" | (string & {}) | number
  proxy?: unknown
  server?: (string & {}) | boolean | Record<string, unknown>
  setupExitSignals?: boolean
  setupMiddlewares?: (middlewares: unknown[], devServer: unknown) => unknown[]
  // eslint-disable-next-line @typescript-eslint/no-redundant-type-constituents
  watchFiles?: string | string[] | unknown
  webSocketServer?: (string & {}) | boolean | Record<string, unknown>
  [key: string]: unknown
}

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

function createDevServerConfig(): WebpackDevServerConfig {
  const devServerYamlConfig = {
    ...shakapackerDevServerYamlConfig
  } as DevServerConfig & Record<string, unknown>
  const liveReload =
    devServerYamlConfig.live_reload !== undefined
      ? devServerYamlConfig.live_reload
      : !devServerYamlConfig.hmr
  delete devServerYamlConfig.live_reload

  const devServerConfig: WebpackDevServerConfig = {
    devMiddleware: {
      publicPath
    },
    hot: devServerYamlConfig.hmr,
    liveReload,
    historyApiFallback: {
      disableDotRule: true
    },
    static: {
      publicPath: contentBase
    }
  }
  delete devServerYamlConfig.hmr

  if (devServerYamlConfig.static) {
    devServerConfig.static = {
      ...devServerConfig.static,
      ...(typeof devServerYamlConfig.static === "object"
        ? (devServerYamlConfig.static as Record<string, unknown>)
        : {})
    }
    delete devServerYamlConfig.static
  }

  if (devServerYamlConfig.client) {
    devServerConfig.client = devServerYamlConfig.client
    delete devServerYamlConfig.client
  }

  Object.keys(devServerYamlConfig).forEach((yamlKey) => {
    const camelYamlKey = snakeToCamelCase(yamlKey)
    if (webpackDevServerMappedKeys.has(camelYamlKey)) {
      devServerConfig[camelYamlKey] = devServerYamlConfig[yamlKey]
    }
  })

  return devServerConfig
}

export default createDevServerConfig
