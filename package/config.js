const { resolve } = require("path")
const { load } = require("js-yaml")
const { existsSync, readFileSync } = require("fs")

const { merge } = require("webpack-merge")
const { ensureTrailingSlash } = require("./utils/helpers")
const { railsEnv } = require("./env")
const configPath = require("./utils/configPath")

const defaultConfigPath = require("./utils/defaultConfigPath")

const getDefaultConfig = () => {
  const defaultConfig = load(readFileSync(defaultConfigPath), "utf8")
  return defaultConfig[railsEnv] || defaultConfig.production
}

const defaults = getDefaultConfig()
let config

if (existsSync(configPath)) {
  const appYmlObject = load(readFileSync(configPath), "utf8")
  const envAppConfig = appYmlObject[railsEnv]

  if (!envAppConfig) {
    /* eslint no-console:0 */
    console.warn(
      `Warning: ${railsEnv} key not found in the configuration file. Using production configuration as a fallback.`
    )
  }

  config = merge(defaults, envAppConfig || {})
} else {
  config = merge(defaults, {})
}

config.outputPath = resolve(config.public_root_path, config.public_output_path)

// Ensure that the publicPath includes our asset host so dynamic imports
// (code-splitting chunks and static assets) load from the CDN instead of a relative path.
const getPublicPath = () => {
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
config.integrity.hash_functions = [...new Set(config.integrity.hash_functions)]

// Backward compatibility: Add webpack_loader property that maps to javascript_transpiler
// Show deprecation warning if webpack_loader is used
if (config.webpack_loader && !config.javascript_transpiler) {
  console.warn("⚠️  DEPRECATION WARNING: The 'webpack_loader' configuration option is deprecated. Please use 'javascript_transpiler' instead as it better reflects its purpose of configuring JavaScript transpilation regardless of the bundler used.")
  config.javascript_transpiler = config.webpack_loader
} else if (!config.javascript_transpiler) {
  config.javascript_transpiler = config.webpack_loader || "babel"
}

// Ensure webpack_loader is always available for backward compatibility
config.webpack_loader = config.javascript_transpiler

module.exports = config
