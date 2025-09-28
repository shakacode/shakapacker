import { resolve } from "path"
import { load } from "js-yaml"
import { existsSync, readFileSync } from "fs"
import { merge } from "webpack-merge"
import { ensureTrailingSlash } from "./utils/helpers"
const { railsEnv } = require("./env")
const configPath = require("./utils/configPath")
const defaultConfigPath = require("./utils/defaultConfigPath")
import { Config, YamlConfig, LegacyConfig } from "./types"
import { isValidYamlConfig, createConfigValidationError, isPartialConfig, isValidConfig } from "./utils/typeGuards"
import { isFileNotFoundError, createFileOperationError } from "./utils/errorHelpers"

const loadAndValidateYaml = (path: string): YamlConfig => {
  const fileContent = readFileSync(path, "utf8")
  const yamlContent = load(fileContent)
  
  if (!isValidYamlConfig(yamlContent)) {
    throw createConfigValidationError(path, railsEnv, "Invalid YAML structure")
  }
  
  return yamlContent
}

const getDefaultConfig = (): Partial<Config> => {
  try {
    const defaultConfig = loadAndValidateYaml(defaultConfigPath)
    return defaultConfig[railsEnv] || defaultConfig.production || {}
  } catch (error) {
    if (isFileNotFoundError(error)) {
      throw createFileOperationError(
        'read', 
        defaultConfigPath, 
        `Default configuration not found at ${defaultConfigPath}. Please ensure Shakapacker is properly installed. You may need to run 'yarn add shakapacker' or 'npm install shakapacker'.`
      )
    }
    throw error
  }
}

const defaults = getDefaultConfig()
let config: Config

if (existsSync(configPath)) {
  try {
    const appYmlObject = loadAndValidateYaml(configPath)
    
    const envAppConfig = appYmlObject[railsEnv]

    if (!envAppConfig) {
      /* eslint no-console:0 */
      console.warn(
        `Warning: ${railsEnv} key not found in the configuration file. Using production configuration as a fallback.`
      )
    }

    // Merge returns the merged type
    const mergedConfig = merge(defaults, envAppConfig || {})
    
    // Validate merged config before type assertion
    if (!isPartialConfig(mergedConfig)) {
      throw createConfigValidationError(
        configPath, 
        railsEnv, 
        `Invalid configuration structure in ${configPath}. Please check your shakapacker.yml syntax and ensure all required fields are properly defined.`
      )
    }
    
    if (!isValidConfig(mergedConfig)) {
      // If it's not a full config but is partial, we can safely cast
      config = mergedConfig as Config
    } else {
      config = mergedConfig
    }
  } catch (error) {
    if (isFileNotFoundError(error)) {
      // File not found is OK, use defaults
      if (!isPartialConfig(defaults)) {
        throw createConfigValidationError(
          defaultConfigPath, 
          railsEnv, 
          `Invalid default configuration. This may indicate a corrupted Shakapacker installation. Try reinstalling with 'yarn add shakapacker --force'.`
        )
      }
      if (!isValidConfig(defaults)) {
        // Defaults might be partial, safe to cast with validation
        config = defaults as Config
      } else {
        config = defaults
      }
    } else {
      throw error
    }
  }
} else {
  // No user config, use defaults
  if (!isPartialConfig(defaults)) {
    throw createConfigValidationError(
      defaultConfigPath, 
      railsEnv, 
      `Invalid default configuration. This may indicate a corrupted Shakapacker installation. Try reinstalling with 'yarn add shakapacker --force'.`
    )
  }
  if (!isValidConfig(defaults)) {
    // Defaults might be partial, safe to cast with validation
    config = defaults as Config
  } else {
    config = defaults
  }
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
// Check for webpack_loader property without type assertion
const configRecord = config as Record<string, any>
const webpackLoader = 'webpack_loader' in configRecord ? String(configRecord.webpack_loader) : undefined

if (webpackLoader && !config.javascript_transpiler) {
  console.warn(
    "⚠️  DEPRECATION WARNING: The 'webpack_loader' configuration option is deprecated. Please use 'javascript_transpiler' instead as it better reflects its purpose of configuring JavaScript transpilation regardless of the bundler used."
  )
  config.javascript_transpiler = webpackLoader
} else if (!config.javascript_transpiler) {
  config.javascript_transpiler = DEFAULT_JAVASCRIPT_TRANSPILER
}

// Ensure webpack_loader is always available for backward compatibility
// Use property assignment instead of type assertion
Object.defineProperty(config, 'webpack_loader', {
  value: config.javascript_transpiler,
  writable: true,
  enumerable: true,
  configurable: true
})

export = config
