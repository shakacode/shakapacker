declare module 'shakapacker' {
  import { Configuration } from 'webpack'

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

  export const config: Config
  export const devServer: Record<string, unknown>
  export function generateWebpackConfig(extraConfig?: Configuration): Configuration
  export const baseConfig: Configuration
  export const env: Env
  export const rules: Record<string, unknown>
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
