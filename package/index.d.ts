import type { Configuration } from "webpack"
import type { Config, DevServerConfig, Env } from "./types"

export declare const config: Config
export declare const devServer: DevServerConfig
export declare const baseConfig: Configuration
export declare const env: Env
export declare const rules: any
export declare const moduleExists: (packageName: string) => boolean
export declare const canProcess: <T = unknown>(
  rule: string,
  fn: (modulePath: string) => T
) => T | null
export declare const inliningCss: boolean
export declare function generateWebpackConfig(
  extraConfig?: Configuration
): Configuration

export * from "webpack-merge"
