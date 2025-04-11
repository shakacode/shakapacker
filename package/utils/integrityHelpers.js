const { existsSync, readFileSync } = require("fs")
const { load } = require("js-yaml")
const configPath = require("./configPath")
const { railsEnv } = require("../env")

/**
 * Loads and retrieves the environment-specific configuration object.
 *
 * @returns {object | null} The configuration object for the current railsEnv,
 * or null if the file/key doesn't exist or an error occurs.
 */
const loadAndCacheConfig = () => {
  if (!existsSync(configPath)) {
    /* eslint no-console:0 */
    console.warn(
      `Warning: Configuration file not found at ${configPath}. Using default integrity settings.`
    )
    return null
  }

  try {
    const fileContent = readFileSync(configPath, "utf8")
    const appYmlObject = load(fileContent)

    const envConfig = appYmlObject[railsEnv]

    if (!envConfig) {
      console.warn(
        `Warning: Environment key "${railsEnv}" not found in ${configPath}. Using default integrity settings.`
      )
      return null
    }

    return envConfig
  } catch (error) {
    console.error(
      `Error reading or parsing config file ${configPath}: ${error}. Using default integrity settings.`
    )
    return null
  }
}

const envAppConfig = loadAndCacheConfig()

/**
 * Checks if integrity is enabled in the configuration.
 * Defaults to false if config is missing, the key is not found, or the setting is not specified.
 * @returns {boolean} True if integrity is enabled, false otherwise.
 */
const isIntegrityEnabled = () => {
  if (
    envAppConfig &&
    envAppConfig.integrity &&
    typeof envAppConfig.integrity.enabled !== "undefined"
  ) {
    return !!envAppConfig.integrity.enabled
  }

  return false
}

/**
 * Gets the list of hash functions specified in the configuration.
 * Defaults to ['sha384'] if config is missing, the key is not found, or the setting is not specified.
 * @returns {string[]} An array of hash function names.
 */
const hashFunctions = () => {
  if (
    envAppConfig &&
    envAppConfig.integrity &&
    envAppConfig.integrity.hash_functions != null
  ) {
    return envAppConfig.integrity.hash_functions
  }

  return ["sha384"]
}

/**
 * Gets the cross-origin attribute value specified in the configuration.
 * Defaults to 'anonymous' if config is missing, the key is not found, or the setting is not specified.
 * @returns {string} The cross-origin attribute value.
 */
const crossOrigin = () => {
  if (
    envAppConfig &&
    envAppConfig.integrity &&
    envAppConfig.integrity.cross_origin != null
  ) {
    return envAppConfig.integrity.cross_origin
  }

  return "anonymous"
}

module.exports = {
  isIntegrityEnabled,
  hashFunctions,
  crossOrigin
}
