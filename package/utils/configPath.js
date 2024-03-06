const fs = require('fs')
const { resolve } = require('path')

const resolveToPhysicalFilePath = () => {
  const shakapackerConfigPath = resolve('config', 'shakapacker.yml')

  if (fs.existsSync(shakapackerConfigPath)) return shakapackerConfigPath
}

module.exports = process.env.SHAKAPACKER_CONFIG || resolveToPhysicalFilePath()
