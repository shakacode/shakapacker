import { load } from "js-yaml"
import { readFileSync } from "fs"
import defaultConfigPath from "./utils/defaultConfigPath"
import configPath from "./utils/configPath"

const NODE_ENVIRONMENTS = ["development", "production", "test"] as const
const DEFAULT = "production"

const railsEnv = process.env.RAILS_ENV
const rawNodeEnv = process.env.NODE_ENV
const nodeEnv =
  rawNodeEnv && NODE_ENVIRONMENTS.includes(rawNodeEnv as any) ? rawNodeEnv : DEFAULT
const isProduction = nodeEnv === "production"
const isDevelopment = nodeEnv === "development"

interface ConfigFile {
  [key: string]: any
}

let config: ConfigFile
try {
  config = load(readFileSync(configPath, "utf8")) as ConfigFile
} catch (error: any) {
  if (error.code === "ENOENT") {
    // File not found, use default configuration
    config = load(readFileSync(defaultConfigPath, "utf8")) as ConfigFile
  } else {
    throw error
  }
}

const availableEnvironments = Object.keys(config).join("|")
const regex = new RegExp(`^(${availableEnvironments})$`, "g")

const runningWebpackDevServer = process.env.WEBPACK_SERVE === "true"

const validatedRailsEnv = railsEnv && railsEnv.match(regex) ? railsEnv : DEFAULT

if (railsEnv && validatedRailsEnv !== railsEnv) {
  /* eslint no-console:0 */
  console.warn(
    `Warning: '${railsEnv}' environment not found in the configuration. Using '${DEFAULT}' configuration as a fallback.`
  )
}

export = {
  railsEnv: validatedRailsEnv,
  nodeEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer
}