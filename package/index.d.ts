declare module 'shakapacker' {
  import { Configuration } from 'webpack'

  export const config: unknown
  export const devServer: unknown
  export function generateWebpackConfig(): Configuration
  export const globalMutableWebpackConfig: Configuration
  export const baseConfig: unknown
  export const env: unknown
  export const rules: unknown
  export function moduleExists(packageName: string): boolean
  export function canProcess(...args: unknown[]): unknown
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
