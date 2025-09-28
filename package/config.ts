import { resolve } from "path"
import { load } from "js-yaml"
import { existsSync, readFileSync } from "fs"
import { merge } from "webpack-merge"
const { ensureTrailingSlash } = require("./utils/helpers")
const { railsEnv } = require("./env")
import configPath from "./utils/configPath"
import defaultConfigPath from "./utils/defaultConfigPath"
import { Config, YamlConfig, LegacyConfig } from "./types"
const { isValidYamlConfig, createConfigValidationError } = require("./utils/typeGuards")

const getDefaultConfig = (): Partial<Config> => {
  try {
    const fileContent = readFileSync(defaultConfigPath, "utf8")
    const defaultConfig = load(fileContent) as YamlConfig
    
    if (!isValidYamlConfig(defaultConfig)) {
      throw createConfigValidationError(defaultConfigPath, railsEnv, "Invalid YAML structure")
    }
    
    return defaultConfig[railsEnv] || defaultConfig.production || {}
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      throw new Error(`Default configuration file not found: ${defaultConfigPath}`)
    }
    throw error
  }
}

const defaults = getDefaultConfig()
let config: Config

if (existsSync(configPath)) {
  try {
    const fileContent = readFileSync(configPath, "utf8")
    const appYmlObject = load(fileContent) as YamlConfig
    
    if (!isValidYamlConfig(appYmlObject)) {
      throw createConfigValidationError(configPath, railsEnv, "Invalid YAML structure")
    }
    
    const envAppConfig = appYmlObject[railsEnv]

    if (!envAppConfig) {
      /* eslint no-console:0 */
      console.warn(
        `Warning: ${railsEnv} key not found in the configuration file. Using production configuration as a fallback.`
      )
    }

    // Merge returns the merged type
    const mergedConfig = merge(defaults, envAppConfig || {})
    config = mergedConfig as Config
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      // File not found is OK, use defaults
      config = defaults as Config
    } else {
      throw error
    }
  }
} else {
  // No user config, use defaults
  config = defaults as Config
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
const webpackLoader = (config as LegacyConfig).webpack_loader
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
const legacyConfig = config as LegacyConfig
legacyConfig.webpack_loader = config.javascript_transpiler

export = config
