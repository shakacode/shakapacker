declare module 'shakapacker' {
  import { Configuration } from 'webpack'

  interface Env {
    railsEnv: string
    nodeEnv: string
    isProduction: boolean
    isDevelopment: boolean
    runningWebpackDevServer: boolean
  }

  export const config: Record<string, unknown>
  export const devServer: Record<string, unknown>
  export function generateWebpackConfig(): Configuration
  export const globalMutableWebpackConfig: Configuration
  export const baseConfig: Record<string, unknown>
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
