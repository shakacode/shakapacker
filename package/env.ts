import { load } from "js-yaml"
import { readFileSync } from "fs"
import defaultConfigPath from "./utils/defaultConfigPath"
import configPath from "./utils/configPath"

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
  if ((error as NodeJS.ErrnoException).code === "ENOENT") {
    // File not found, use default configuration
    config = load(readFileSync(defaultConfigPath, "utf8")) as ConfigFile
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

// Export as CommonJS for backward compatibility
export = {
  railsEnv: validatedRailsEnv,
  nodeEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer
}
