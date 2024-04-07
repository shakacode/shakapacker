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

module.exports = config
