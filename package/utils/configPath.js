const fs = require('fs')
const { resolve } = require('path')
const { setShakapackerEnvVariablesForBackwardCompatibility } = require('./helpers')

setShakapackerEnvVariablesForBackwardCompatibility()

// For backward compatibility
const resolveToPhysicalFilePath = () => {
  const shakapackerConfigPath = resolve('config', 'shakapacker.yml')
  const webpackerConfigPath = resolve('config', 'webpacker.yml')

  if (fs.existsSync(shakapackerConfigPath)) return shakapackerConfigPath
  if (fs.existsSync(webpackerConfigPath)) return webpackerConfigPath

  // If neither of files exist, try to resolve to shakapacker.yml to get more relevant error
  return shakapackerConfigPath
}

module.exports = process.env.SHAKAPACKER_CONFIG || resolveToPhysicalFilePath()
