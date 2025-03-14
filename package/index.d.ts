declare module 'shakapacker' {
  import { Configuration, RuleSetRule } from 'webpack'
  import { Configuration as WebpackDevServerConfiguration } from 'webpack-dev-server'

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

  type CamelToSnakeCase<S extends string> = S extends `${infer First}${infer Rest}`
    ? Rest extends Uncapitalize<Rest> // Check if `Rest` starts with a lowercase letter
      ? `${Lowercase<First>}${CamelToSnakeCase<Rest>}`
      : `${Lowercase<First>}_${CamelToSnakeCase<Uncapitalize<Rest>>}`
    : S

  type SnakeCase<T> = {
    [K in keyof T as CamelToSnakeCase<string & K>]: T[K];
  }

  type DevServerConfig = SnakeCase<Omit<WebpackDevServerConfiguration, 'hot'>> & {
    hmr?: boolean
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
