/**
 * Type definitions for environment configurations
 * These types are exported for consumer use
 */

import type {
  Configuration as WebpackConfiguration,
  WebpackPluginInstance
} from "webpack"
import type { Configuration as DevServerConfiguration } from "webpack-dev-server"

/**
 * Webpack configuration extended with dev server support
 */
export interface WebpackConfigWithDevServer extends WebpackConfiguration {
  devServer?: DevServerConfiguration
  plugins?: WebpackPluginInstance[]
}

/**
 * Rspack plugin interface
 * Rspack plugins follow a similar pattern to webpack but may have different internals
 */
export interface RspackPlugin {
  new (...args: unknown[]): {
    apply(compiler: unknown): void
    [key: string]: unknown
  }
}

/**
 * Rspack dev server configuration
 * Similar to webpack-dev-server but with some rspack-specific options
 */
export interface RspackDevServerConfig {
  port?: number | string | "auto"
  host?: string
  hot?: boolean | "only"
  historyApiFallback?: boolean | Record<string, unknown>
  headers?: Record<string, string | string[]>
  proxy?: unknown
  static?: boolean | string | Array<string | Record<string, unknown>>
  devMiddleware?: {
    writeToDisk?: boolean | ((filePath: string) => boolean)
    publicPath?: string
    [key: string]: unknown
  }
  [key: string]: unknown
}

/**
 * Rspack configuration with dev server support
 */
export interface RspackConfigWithDevServer {
  mode?: "development" | "production" | "none"
  devtool?: string | false
  devServer?: RspackDevServerConfig
  plugins?: RspackPlugin[]
  module?: WebpackConfiguration["module"]
  resolve?: WebpackConfiguration["resolve"]
  entry?: WebpackConfiguration["entry"]
  output?: WebpackConfiguration["output"]
  optimization?: WebpackConfiguration["optimization"]
  [key: string]: unknown
}

/**
 * Compression plugin options interface
 */
export interface CompressionPluginOptions {
  filename: string
  algorithm: string | "gzip" | "brotliCompress"
  test: RegExp
  threshold?: number
  minRatio?: number
  deleteOriginalAssets?: boolean
}

/**
 * Compression plugin constructor type
 */
export type CompressionPluginConstructor = new (
  options: CompressionPluginOptions
) => WebpackPluginInstance

/**
 * React Refresh plugin types
 */
export interface _ReactRefreshWebpackPlugin {
  new (options?: Record<string, unknown>): WebpackPluginInstance
}

export interface _ReactRefreshRspackPlugin {
  new (options?: Record<string, unknown>): RspackPlugin
}
