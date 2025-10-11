import * as webpackMerge from "webpack-merge"
import type { Configuration } from "webpack"
declare const _default: {
  customizeArray: typeof webpackMerge.customizeArray
  customizeObject: typeof webpackMerge.customizeObject
  CustomizeRule: typeof webpackMerge.CustomizeRule
  merge: typeof webpackMerge.merge
  default: typeof webpackMerge.merge
  mergeWithCustomize: typeof webpackMerge.mergeWithCustomize
  mergeWithRules: typeof webpackMerge.mergeWithRules
  unique: typeof webpackMerge.unique
  config: import("./types").Config
  devServer: import("./types").DevServerConfig
  generateWebpackConfig: (
    extraConfig?: Configuration,
    ...extraArgs: unknown[]
  ) => Configuration
  baseConfig: Configuration
  env: {
    railsEnv: any
    nodeEnv: any
    isProduction: boolean
    isDevelopment: boolean
    runningWebpackDevServer: boolean
  }
  rules: any
  moduleExists: (packageName: string) => boolean
  canProcess: <T = unknown>(
    rule: string,
    fn: (modulePath: string) => T
  ) => T | null
  inliningCss: boolean
}
export = _default
//# sourceMappingURL=index.d.ts.map
