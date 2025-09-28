import { resolve } from "path"
import { load } from "js-yaml"
import { existsSync, readFileSync } from "fs"
import { merge } from "webpack-merge"
const { ensureTrailingSlash } = require("./utils/helpers")
const { railsEnv } = require("./env")
const configPath = require("./utils/configPath")
const defaultConfigPath = require("./utils/defaultConfigPath")
import { Config } from "./types"

const getDefaultConfig = (): any => {
  const defaultConfig = load(readFileSync(defaultConfigPath, "utf8")) as any
  return defaultConfig[railsEnv] || defaultConfig.production
}

const defaults = getDefaultConfig()
let config: Config

if (existsSync(configPath)) {
  const appYmlObject = load(readFileSync(configPath, "utf8")) as any
  const envAppConfig = appYmlObject[railsEnv]

  if (!envAppConfig) {
    /* eslint no-console:0 */
    console.warn(
      `Warning: ${railsEnv} key not found in the configuration file. Using production configuration as a fallback.`
    )
  }

  config = merge(defaults, envAppConfig || {}) as Config
} else {
  config = merge(defaults, {}) as Config
}

config.outputPath = resolve(config.public_root_path, config.public_output_path)

// Ensure that the publicPath includes our asset host so dynamic imports
// (code-splitting chunks and static assets) load from the CDN instead of a relative path.
const getPublicPath = (): string => {
  const rootUrl = ensureTrailingSlash(process.env.SHAKAPACKER_ASSET_HOST || "/")
  return `${rootUrl}${config.public_output_path}/`
}

config.publicPath = getPublicPath()
config.publicPathWithoutCDN = `/${config.public_output_path}/`

if (config.manifest_path) {
  config.manifestPath = resolve(config.manifest_path)
} else {
  config.manifestPath = resolve(config.outputPath, "manifest.json")
}
// Ensure no duplicate hash functions exist in the returned config object
if (config.integrity?.hash_functions) {
  config.integrity.hash_functions = [...new Set(config.integrity.hash_functions)]
}

// Allow ENV variable to override assets_bundler
if (process.env.SHAKAPACKER_ASSETS_BUNDLER) {
  config.assets_bundler = process.env.SHAKAPACKER_ASSETS_BUNDLER
}

// Define clear defaults
const DEFAULT_JAVASCRIPT_TRANSPILER =
  config.assets_bundler === "rspack" ? "swc" : "babel"

// Backward compatibility: Add webpack_loader property that maps to javascript_transpiler
// Show deprecation warning if webpack_loader is used
const webpackLoader = (config as any).webpack_loader
if (webpackLoader && !config.javascript_transpiler) {
  console.warn(
    "⚠️  DEPRECATION WARNING: The 'webpack_loader' configuration option is deprecated. Please use 'javascript_transpiler' instead as it better reflects its purpose of configuring JavaScript transpilation regardless of the bundler used."
  )
  config.javascript_transpiler = webpackLoader
} else if (!config.javascript_transpiler) {
  config.javascript_transpiler =
    webpackLoader || DEFAULT_JAVASCRIPT_TRANSPILER
}

// Ensure webpack_loader is always available for backward compatibility
;(config as any).webpack_loader = config.javascript_transpiler

export = config