const { load } = require("js-yaml")
const { readFileSync } = require("fs")
const defaultConfigPath = require("./utils/defaultConfigPath")

const NODE_ENVIRONMENTS = ["development", "production", "test"]
const DEFAULT = "production"
const configPath = require("./utils/configPath")

const railsEnv = process.env.RAILS_ENV
const rawNodeEnv = process.env.NODE_ENV
const nodeEnv =
  rawNodeEnv && NODE_ENVIRONMENTS.includes(rawNodeEnv) ? rawNodeEnv : DEFAULT
const isProduction = nodeEnv === "production"
const isDevelopment = nodeEnv === "development"

let config
try {
  config = load(readFileSync(configPath), "utf8")
} catch (error) {
  if (error.code === "ENOENT") {
    // File not found, use default configuration
    config = load(readFileSync(defaultConfigPath), "utf8")
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

module.exports = {
  railsEnv: validatedRailsEnv,
  nodeEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer
}
