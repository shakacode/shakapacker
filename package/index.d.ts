declare module 'shakapacker' {
  import { Configuration, RuleSetRule } from 'webpack'
  import * as https from 'node:https';

  export interface Config {
    source_path: string
    source_entry_path: string
    nested_entries: boolean
    css_extract_ignore_order_warnings: boolean
    public_root_path: string
    public_output_path: string
    cache_path: string
    webpack_compile_output: boolean
    shakapacker_precompile: boolean
    additional_paths: string[]
    cache_manifest: boolean
    webpack_loader: string
    ensure_consistent_versioning: boolean
    compiler_strategy: string
    useContentHash: boolean
    compile: boolean,
    outputPath: string
    publicPath: string
    publicPathWithoutCDN: string
    manifestPath: string
  }

  export interface Env {
    railsEnv: string
    nodeEnv: string
    isProduction: boolean
    isDevelopment: boolean
    runningWebpackDevServer: boolean
  }

  type Header = Array<{ key: string; value: string }> | Record<string, string | string[]>
  type ServerType = 'http' | 'https' | 'spdy'
  type WebSocketType = 'sockjs' | 'ws'

  /**
   * This has the same keys and behavior as https://webpack.js.org/configuration/dev-server/ except:
   * 1. `hot` is replaced by `hmr`;
   * 2. Camel-cased properties are replaced by snake-cased ones.
   * @see {import('webpack-dev-server').Configuration}
   */
  interface DevServerConfig {
    allowed_hosts?: 'all' | 'auto' | string | string[]
    bonjour?: boolean | Record<string, unknown> // bonjour.BonjourOptions
    client?: Record<string, unknown> // Client
    compress?: boolean
    dev_middleware?: Record<string, unknown> // webpackDevMiddleware.Options
    headers?: Header | (() => Header)
    history_api_fallback?: boolean | Record<string, unknown> // HistoryApiFallbackOptions
    hmr?: 'only' | boolean
    host?: 'local-ip' | 'local-ipv4' | 'local-ipv6' | string
    http2?: boolean
    https?: boolean | https.ServerOptions
    ipc?: boolean | string
    magic_html?: boolean
    live_reload?: boolean
    open?: boolean | string | string[] | Record<string, unknown> | Record<string, unknown>[]
    port?: 'auto' | string | number
    proxy?: unknown // ProxyConfigMap | ProxyConfigArray
    setup_exit_signals?: boolean
    static?: boolean | string | unknown // Static | Array<string | Static>
    watch_files?: string | string[] | unknown // WatchFiles | Array<WatchFiles | string>
    web_socket_server?: string | boolean | WebSocketType | { type?: string | boolean | WebSocketType, options?: Record<string, unknown> }
    server?: string | boolean | ServerType | { type?: string | boolean | ServerType, options?: https.ServerOptions }
    [otherWebpackDevServerConfigKey: string]: unknown
  }

  export const config: Config
  export const devServer: DevServerConfig
  export function generateWebpackConfig(extraConfig?: Configuration): Configuration
  export const baseConfig: Configuration
  export const env: Env
  export const rules: RuleSetRule[]
  export function moduleExists(packageName: string): boolean
  export function canProcess<T = unknown>(rule: string, fn: (modulePath: string) => T): T | null
  export const inliningCss: boolean
  export * from 'webpack-merge'
}

declare module 'shakapacker/package/babel/preset.js' {
  import { ConfigAPI, PluginItem, TransformOptions } from '@babel/core'

  interface RequiredTransformOptions {
    plugins: PluginItem[]
    presets: PluginItem[]
  }

  const defaultConfigFunc: (
    api: ConfigAPI
  ) => TransformOptions & RequiredTransformOptions

  export = defaultConfigFunc
}
