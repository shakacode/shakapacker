import { load } from "js-yaml"
import { readFileSync } from "fs"
const defaultConfigPath = require("./utils/defaultConfigPath")
const configPath = require("./utils/configPath")
const { isFileNotFoundError } = require("./utils/errorHelpers")

const NODE_ENVIRONMENTS = ["development", "production", "test"] as const
const DEFAULT = "production"

const initialRailsEnv = process.env.RAILS_ENV
const rawNodeEnv = process.env.NODE_ENV
const nodeEnv =
  rawNodeEnv && NODE_ENVIRONMENTS.includes(rawNodeEnv as typeof NODE_ENVIRONMENTS[number]) ? rawNodeEnv : DEFAULT
const isProduction = nodeEnv === "production"
const isDevelopment = nodeEnv === "development"

interface ConfigFile {
  [environment: string]: Record<string, unknown>
}

let config: ConfigFile
try {
  config = load(readFileSync(configPath, "utf8")) as ConfigFile
} catch (error: unknown) {
  if (isFileNotFoundError(error)) {
    // File not found, use default configuration
    try {
      config = load(readFileSync(defaultConfigPath, "utf8")) as ConfigFile
    } catch (defaultError) {
      throw new Error(
        `Failed to load Shakapacker configuration.\n` +
        `Neither user config (${configPath}) nor default config (${defaultConfigPath}) could be loaded.\n\n` +
        `To fix this issue:\n` +
        `1. Create a config/shakapacker.yml file in your project\n` +
        `2. Or set the SHAKAPACKER_CONFIG environment variable to point to your config file\n` +
        `3. Or reinstall Shakapacker to restore the default configuration:\n` +
        `   npm install shakapacker --force\n` +
        `   yarn add shakapacker --force`
      )
    }
  } else {
    throw error
  }
}

const availableEnvironments = Object.keys(config).join("|")
const regex = new RegExp(`^(${availableEnvironments})$`, "g")

const runningWebpackDevServer = process.env.WEBPACK_SERVE === "true"

const validatedRailsEnv = initialRailsEnv && initialRailsEnv.match(regex) ? initialRailsEnv : DEFAULT

if (initialRailsEnv && validatedRailsEnv !== initialRailsEnv) {
  /* eslint no-console:0 */
  console.warn(
    `Warning: '${initialRailsEnv}' environment not found in the configuration. Using '${DEFAULT}' configuration as a fallback.`
  )
}

export = {
  railsEnv: validatedRailsEnv,
  nodeEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer
}
