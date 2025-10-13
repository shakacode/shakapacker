/**
 * Manual type definitions for Shakapacker package exports.
 *
 * This file is manually maintained because TypeScript cannot infer types
 * from the `export =` syntax with dynamic require() calls in index.ts.
 *
 * When adding/modifying exports in index.ts, update this file accordingly.
 */

import type { Configuration, RuleSetRule } from "webpack"
import type { Config, DevServerConfig, Env } from "./types"

/**
 * The shape of the Shakapacker module exports.
 * This interface represents the object exported via CommonJS `export =`.
 */
interface ShakapackerExports {
  /** Shakapacker configuration from shakapacker.yml */
  config: Config
  /** Development server configuration */
  devServer: DevServerConfig
  /** Base webpack/rspack configuration */
  baseConfig: Configuration
  /** Environment configuration (railsEnv, nodeEnv, etc.) */
  env: Env
  /** Array of webpack/rspack loader rules */
  rules: RuleSetRule[]
  /** Check if a module exists in node_modules */
  moduleExists: (packageName: string) => boolean
  /** Process a file if a specific loader is available */
  canProcess: <T = unknown>(
    rule: string,
    fn: (modulePath: string) => T
  ) => T | null
  /** Whether CSS should be inlined (dev server with HMR) */
  inliningCss: boolean
  /** Generate webpack configuration with optional custom config */
  generateWebpackConfig: (extraConfig?: Configuration) => Configuration
  /** webpack-merge's merge function */
  merge: typeof import("webpack-merge").merge
  /** webpack-merge's mergeWithCustomize function */
  mergeWithCustomize: typeof import("webpack-merge").mergeWithCustomize
  /** webpack-merge's mergeWithRules function */
  mergeWithRules: typeof import("webpack-merge").mergeWithRules
  /** webpack-merge's unique function */
  unique: typeof import("webpack-merge").unique
}

declare const shakapacker: ShakapackerExports
export = shakapacker
