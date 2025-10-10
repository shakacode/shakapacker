// These are the raw shakapacker dev server config settings from the YML file with ENV overrides applied.
import { DevServerConfig } from "./types"
import { isBoolean } from "./utils/helpers"
import config from "./config"

const envFetch = (key: string): string | boolean | undefined => {
  const value = process.env[key]
  if (!value) return undefined
  return isBoolean(value) ? JSON.parse(value) : value
}

const devServerConfig: DevServerConfig | undefined = config.dev_server

if (devServerConfig) {
  const envPrefix = devServerConfig.env_prefix || "SHAKAPACKER_DEV_SERVER"

  Object.keys(devServerConfig).forEach((key) => {
    const envValue = envFetch(`${envPrefix}_${key.toUpperCase()}`)
    if (envValue !== undefined) {
      // Use bracket notation to avoid ASI issues
      ;(devServerConfig as Record<string, unknown>)[key] = envValue
    }
  })
}

export default devServerConfig || {}
