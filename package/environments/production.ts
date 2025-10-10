/**
 * Production environment configuration for webpack and rspack bundlers
 * @module environments/production
 */

/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

import { resolve } from "path"
import { merge } from "webpack-merge"
import baseConfig from "./base"
import { moduleExists } from "../utils/helpers"
import config from "../config"
import type {
  Configuration as WebpackConfiguration,
  WebpackPluginInstance
} from "webpack"
import type { CompressionPluginConstructor } from "./types"

const optimizationPath = resolve(
  __dirname,
  "..",
  "optimization",
  `${config.assets_bundler}.js`
)
const { getOptimization } = require(optimizationPath)

let CompressionPlugin: CompressionPluginConstructor | null = null
if (moduleExists("compression-webpack-plugin")) {
  // eslint-disable-next-line global-require
  CompressionPlugin = require("compression-webpack-plugin")
}

/**
 * Generate production plugins including compression
 * @returns Array of webpack plugins for production
 */
const getPlugins = (): WebpackPluginInstance[] => {
  const plugins: WebpackPluginInstance[] = []

  if (CompressionPlugin) {
    plugins.push(
      new CompressionPlugin({
        filename: "[path][base].gz[query]",
        algorithm: "gzip",
        test: /\.(js|css|html|json|ico|svg|eot|otf|ttf|map)$/
      })
    )

    if ("brotli" in process.versions) {
      plugins.push(
        new CompressionPlugin({
          filename: "[path][base].br[query]",
          algorithm: "brotliCompress",
          test: /\.(js|css|html|json|ico|svg|eot|otf|ttf|map)$/
        })
      )
    }
  }

  return plugins
}

/**
 * Production configuration with optimizations and compression
 */
const productionConfig: Partial<WebpackConfiguration> = {
  devtool: "source-map",
  stats: "normal",
  bail: true,
  plugins: getPlugins(),
  optimization: getOptimization()
}

if (config.useContentHash === false) {
  // eslint-disable-next-line no-console
  console.warn(`⚠️ WARNING
Setting 'useContentHash' to 'false' in the production environment (specified by NODE_ENV environment variable) is not allowed!
Content hashes get added to the filenames regardless of setting useContentHash in 'shakapacker.yml' to false.
`)
}

export default merge(baseConfig, productionConfig)
