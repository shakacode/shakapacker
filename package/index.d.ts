declare module 'shakapacker' {
  import { Configuration } from 'webpack'

  export { merge } from 'webpack-merge'
  export const globalMutableWebpackConfig: Configuration
  export function generateWebpackConfig(): Configuration
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
