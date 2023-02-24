const { resolve } = require('path')
const { setShakapackerEnvVariablesForBackwardCompatibility, fileExists } = require('./utils/helpers')

setShakapackerEnvVariablesForBackwardCompatibility()

// For backward compatibility
const resolveToPhysicalFilePath = () => {
  const shakapackerConfigPath = resolve('config', 'shakapacker.yml')
  const webpackerConfigPath = resolve('config', 'webpacker.yml')

  if (fileExists(shakapackerConfigPath)) return shakapackerConfigPath
  if (fileExists(webpackerConfigPath)) return webpackerConfigPath

  // If neither of files exist, try to resolve to shakapacker.yml to get more relevant error
  return shakapackerConfigPath
}

module.exports = process.env.SHAKAPACKER_CONFIG || resolveToPhysicalFilePath()
