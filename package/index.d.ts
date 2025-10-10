import type Config from "./config"
import type DevServer from "./dev_server"
import type BaseConfig from "./environments/base"
import type InliningCss from "./utils/inliningCss"
import type { Configuration } from "webpack"

// Re-export env values
export {
  railsEnv,
  nodeEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer
} from "./env"

// Re-export utilities
export { moduleExists, canProcess } from "./utils/helpers"

// Re-export from webpack-merge
export * from "webpack-merge"

// Named exports
export const config: Config
export const devServer: DevServer
export const baseConfig: BaseConfig
export const inliningCss: InliningCss
export const rules: any

export function generateWebpackConfig(
  extraConfig?: Configuration,
  ...extraArgs: unknown[]
): Configuration

// Default export for backward compatibility
// Includes all webpack-merge exports plus shakapacker-specific properties
interface DefaultExport {
  config: Config
  devServer: DevServer
  generateWebpackConfig: typeof generateWebpackConfig
  baseConfig: BaseConfig
  env: {
    railsEnv: string
    nodeEnv: string
    isProduction: boolean
    isDevelopment: boolean
    runningWebpackDevServer: boolean
  }
  rules: any
  moduleExists: typeof moduleExists
  canProcess: typeof canProcess
  inliningCss: InliningCss
  // webpack-merge exports spread into default export
  merge: typeof import("webpack-merge").merge
  mergeWithCustomize: typeof import("webpack-merge").mergeWithCustomize
  mergeWithRules: typeof import("webpack-merge").mergeWithRules
  unique: typeof import("webpack-merge").unique
  customizeArray: typeof import("webpack-merge").customizeArray
  customizeObject: typeof import("webpack-merge").customizeObject
  CustomizeRule: typeof import("webpack-merge").CustomizeRule
}

declare const _default: DefaultExport
export default _default
