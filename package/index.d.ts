// Named exports
export { default as config } from "./config"
export { default as devServer } from "./dev_server"
export { default as baseConfig } from "./environments/base"
export {
  railsEnv,
  nodeEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer
} from "./env"
export { moduleExists, canProcess } from "./utils/helpers"
export { default as inliningCss } from "./utils/inliningCss"
export * from "webpack-merge"

// @ts-ignore: webpack is an optional peer dependency
import type { Configuration } from "webpack"

export const rules: any
export function generateWebpackConfig(
  extraConfig?: Configuration,
  ...extraArgs: unknown[]
): Configuration

// Default export for backward compatibility
declare const _default: {
  config: typeof config
  devServer: typeof devServer
  generateWebpackConfig: typeof generateWebpackConfig
  baseConfig: typeof baseConfig
  env: {
    railsEnv: typeof railsEnv
    nodeEnv: typeof nodeEnv
    isProduction: typeof isProduction
    isDevelopment: typeof isDevelopment
    runningWebpackDevServer: typeof runningWebpackDevServer
  }
  rules: typeof rules
  moduleExists: typeof moduleExists
  canProcess: typeof canProcess
  inliningCss: typeof inliningCss
}
export default _default
