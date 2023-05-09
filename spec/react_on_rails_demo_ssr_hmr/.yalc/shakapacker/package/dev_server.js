const { isBoolean } = require('./utils/helpers')
const config = require('./config')

const fetchFromEnv = (key) => {
  const value = process.env[key]
  return isBoolean(value) ? JSON.parse(value) : value
}

const devServerFromConfigFile = config.dev_server

if (devServerFromConfigFile) {
  const envPrefix = devServerFromConfigFile.env_prefix || 'SHAKAPACKER_DEV_SERVER'

  Object.keys(devServerFromConfigFile).forEach((key) => {
    const envValue = fetchFromEnv(`${envPrefix}_${key.toUpperCase()}`)
    if (envValue !== undefined) devServerFromConfigFile[key] = envValue
  })
}

module.exports = devServerFromConfigFile || {}
