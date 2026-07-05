import { dirname, resolve, sep } from "path"
import { load } from "js-yaml"
import { existsSync, readFileSync } from "fs"
import { merge } from "webpack-merge"
const { ensureTrailingSlash, packageDependencyExists } =
  require("./utils/helpers") as {
    ensureTrailingSlash: (path: string) => string
    packageDependencyExists: (
      packageName: string,
      packageRootPaths: string[]
    ) => boolean
  }
const { railsEnv } = require("./env")
const configPath = require("./utils/configPath")
const defaultConfigPath = require("./utils/defaultConfigPath")
const { sanitizeEnvValue } = require("./utils/pathValidation") as {
  sanitizeEnvValue: (value: string | undefined) => string | undefined
}
const requestedRailsEnv = sanitizeEnvValue(process.env.RAILS_ENV) || railsEnv
import { Config, YamlConfig } from "./types"
const {
  isValidYamlConfig,
  createConfigValidationError,
  isPartialConfig
} = require("./utils/typeGuards")
const {
  isFileNotFoundError,
  createFileOperationError
} = require("./utils/errorHelpers")

const loadAndValidateYaml = (path: string): YamlConfig => {
  const fileContent = readFileSync(path, "utf8")
  const yamlContent = load(fileContent)

  if (!isValidYamlConfig(yamlContent)) {
    throw createConfigValidationError(
      path,
      requestedRailsEnv,
      "Invalid YAML structure"
    )
  }

  return yamlContent as YamlConfig
}

const getDefaultConfig = (): Partial<Config> => {
  try {
    const defaultConfig = loadAndValidateYaml(defaultConfigPath)
    return defaultConfig[requestedRailsEnv] || defaultConfig.production || {}
  } catch (error) {
    if (isFileNotFoundError(error)) {
      throw createFileOperationError(
        "read",
        defaultConfigPath,
        `Default configuration not found at ${defaultConfigPath}. Please ensure Shakapacker is properly installed. You may need to run 'yarn add shakapacker' or 'npm install shakapacker'.`
      )
    }
    throw error
  }
}

const defaults = getDefaultConfig()
let config: Config
let appConfigHasJavascriptTranspiler = false
let appConfigHasWebpackLoader = false
let appConfigWebpackLoader: string | undefined
let cachedPackageRootPaths: string[] | undefined

const pathWithin = (path: string, parent: string): boolean =>
  path === parent || path.startsWith(`${parent}${sep}`)

const javascriptPackageRootPath = (): string => {
  const sourcePath = resolve(config.source_path)
  const appRoot = resolve(process.cwd())

  if (!pathWithin(sourcePath, appRoot)) {
    return appRoot
  }

  let current = sourcePath
  while (true) {
    if (existsSync(resolve(current, "package.json"))) {
      return current
    }
    if (current === appRoot) {
      return appRoot
    }

    const parent = dirname(current)
    if (parent === current) {
      return appRoot
    }

    current = parent
  }
}

const packageRootPaths = (): string[] => {
  cachedPackageRootPaths ||= [
    ...new Set([javascriptPackageRootPath(), resolve(process.cwd())])
  ]
  return cachedPackageRootPaths
}

const packageDependencyInstalled = (packageName: string): boolean =>
  packageDependencyExists(packageName, packageRootPaths())

const presentString = (value: unknown): value is string =>
  typeof value === "string" && value.trim().length > 0

const configuredValue = (value: unknown): boolean =>
  value !== null &&
  value !== undefined &&
  !(typeof value === "string" && value.trim().length === 0)

if (existsSync(configPath)) {
  try {
    const appYmlObject = loadAndValidateYaml(configPath)

    const requestedEnvAppConfig = appYmlObject[requestedRailsEnv]
    const envAppConfig = requestedEnvAppConfig || appYmlObject.production
    if (envAppConfig) {
      const envAppConfigRecord = envAppConfig as Record<string, unknown>
      const javascriptTranspiler = envAppConfigRecord.javascript_transpiler
      appConfigHasJavascriptTranspiler =
        Object.prototype.hasOwnProperty.call(
          envAppConfigRecord,
          "javascript_transpiler"
        ) && configuredValue(javascriptTranspiler)
      const webpackLoader = envAppConfigRecord.webpack_loader
      if (presentString(webpackLoader)) {
        appConfigHasWebpackLoader = true
        appConfigWebpackLoader = webpackLoader
      }
    }

    if (!requestedEnvAppConfig) {
      console.warn(
        `[SHAKAPACKER WARNING] Environment '${requestedRailsEnv}' not found in ${configPath}\n` +
          `Available environments: ${Object.keys(appYmlObject).join(", ")}\n` +
          `Using 'production' configuration as fallback.\n\n` +
          `To fix this, either:\n` +
          `  - Add a '${requestedRailsEnv}' section to your shakapacker.yml\n` +
          `  - Set RAILS_ENV to one of the available environments\n` +
          `  - Copy settings from another environment as a starting point`
      )
    }

    // Merge returns the merged type
    const mergedConfig = merge(defaults, envAppConfig || {})

    // Validate merged config before type assertion
    if (!isPartialConfig(mergedConfig)) {
      throw createConfigValidationError(
        configPath,
        requestedRailsEnv,
        `Invalid configuration structure in ${configPath}. Please check your shakapacker.yml syntax and ensure all required fields are properly defined.`
      )
    }

    // After merging with defaults, config should be complete
    // Use type assertion only after validation
    config = mergedConfig as Config
  } catch (error) {
    if (isFileNotFoundError(error)) {
      // File not found is OK, use defaults
      if (!isPartialConfig(defaults)) {
        throw createConfigValidationError(
          defaultConfigPath,
          requestedRailsEnv,
          `Invalid default configuration. This may indicate a corrupted Shakapacker installation. Try reinstalling with 'yarn add shakapacker --force'.`
        )
      }
      // Using defaults only, might be partial
      config = defaults as Config
    } else {
      throw error
    }
  }
} else {
  // No user config, use defaults
  if (!isPartialConfig(defaults)) {
    throw createConfigValidationError(
      defaultConfigPath,
      requestedRailsEnv,
      `Invalid default configuration. This may indicate a corrupted Shakapacker installation. Try reinstalling with 'yarn add shakapacker --force'.`
    )
  }
  // Using defaults only, might be partial
  config = defaults as Config
}

config.outputPath = resolve(config.public_root_path, config.public_output_path)

if (config.private_output_path) {
  config.privateOutputPath = resolve(config.private_output_path)
}

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
  config.integrity.hash_functions = [
    ...new Set(config.integrity.hash_functions)
  ]
}

// Ensure assets_bundler has a default value
if (!config.assets_bundler) {
  config.assets_bundler = "webpack"
}

// Allow ENV variable to override assets_bundler
if (process.env.SHAKAPACKER_ASSETS_BUNDLER) {
  config.assets_bundler = process.env.SHAKAPACKER_ASSETS_BUNDLER
}

// Define clear defaults
// Keep Babel as default for webpack to maintain backward compatibility
// Use SWC for rspack as it's a newer bundler where we can set modern defaults
const DEFAULT_JAVASCRIPT_TRANSPILER =
  config.assets_bundler === "rspack" ? "swc" : "babel"

const IMPLICIT_SWC_BABEL_FALLBACK_WARNING =
  "`javascript_transpiler` is not set in config/shakapacker.yml. " +
  "Shakapacker defaults to SWC, but swc-loader is not installed and Babel was detected, so Babel will be used. " +
  "Set `javascript_transpiler: babel` (or `swc`) explicitly to silence this message. " +
  "See https://github.com/shakacode/shakapacker/blob/main/docs/transpiler-migration.md"

const transpilerConfiguredByApp =
  appConfigHasJavascriptTranspiler || appConfigHasWebpackLoader

const shouldFallbackImplicitSwcToBabel = (): boolean =>
  !transpilerConfiguredByApp &&
  config.assets_bundler === "webpack" &&
  config.javascript_transpiler === "swc" &&
  !packageDependencyInstalled("swc-loader") &&
  packageDependencyInstalled("babel-loader")

if (
  !appConfigHasJavascriptTranspiler &&
  !appConfigHasWebpackLoader &&
  !config.javascript_transpiler
) {
  config.javascript_transpiler =
    defaults.javascript_transpiler || DEFAULT_JAVASCRIPT_TRANSPILER
}

// Allow environment variable to override javascript_transpiler
if (process.env.SHAKAPACKER_JAVASCRIPT_TRANSPILER) {
  config.javascript_transpiler = process.env.SHAKAPACKER_JAVASCRIPT_TRANSPILER
} else if (
  appConfigHasWebpackLoader &&
  !appConfigHasJavascriptTranspiler &&
  appConfigWebpackLoader
) {
  console.warn(
    "[SHAKAPACKER DEPRECATION] The 'webpack_loader' configuration option is deprecated.\n" +
      "Please use 'javascript_transpiler' instead as it better reflects its purpose of configuring JavaScript transpilation regardless of the bundler used."
  )
  config.javascript_transpiler = appConfigWebpackLoader
} else if (!config.javascript_transpiler) {
  config.javascript_transpiler = DEFAULT_JAVASCRIPT_TRANSPILER
} else if (shouldFallbackImplicitSwcToBabel()) {
  console.warn(IMPLICIT_SWC_BABEL_FALLBACK_WARNING)
  config.javascript_transpiler = "babel"
}

// Ensure webpack_loader is always available for backward compatibility
Object.defineProperty(config, "webpack_loader", {
  value: config.javascript_transpiler,
  writable: true,
  enumerable: true,
  configurable: true
})

export = config
