declare module 'shakapacker' {
  import { Configuration } from 'webpack'

  export * from 'webpack-merge'
  export const globalMutableWebpackConfig: Configuration
  export function generateWebpackConfig(): Configuration
  export const inliningCss: boolean
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
