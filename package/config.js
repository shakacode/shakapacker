const { resolve } = require('path')
// const { load } = require('js-yaml')
// const { readFileSync } = require('fs')
const { merge } = require('webpack-merge')
const configParser = require('./configParser')
const {
  ensureTrailingSlash,
  setShakapackerEnvVariablesForBackwardCompatibility
} = require('./utils/helpers')
const { railsEnv } = require('./env')
const configPath = require('./configPath')

const bundledConfigPath = require.resolve('../config/shakapacker.yml')

const completeDefaultConfig = configParser(bundledConfigPath)
const defaultConfig = completeDefaultConfig[railsEnv] || completeDefaultConfig.production

const config = (customConfig = configParser(configPath)[railsEnv]) => {
  const result = merge(defaultConfig, customConfig)

  result.outputPath = resolve(result.public_root_path, result.public_output_path)
  
  // Ensure that the publicPath includes our asset host so dynamic imports
  // (code-splitting chunks and static assets) load from the CDN instead of a relative path.
  const getPublicPath = () => {
    setShakapackerEnvVariablesForBackwardCompatibility()
    const rootUrl = ensureTrailingSlash(process.env.SHAKAPACKER_ASSET_HOST || '/')
    return `${rootUrl}${result.public_output_path}/`
  }
  
  result.publicPath = getPublicPath()
  result.publicPathWithoutCDN = `/${result.public_output_path}/`

  if (result.manifest_path) {
    result.manifestPath = resolve(result.manifest_path)
  } else {
    result.manifestPath = resolve(result.outputPath, 'manifest.json')
  }

  return result
}


module.exports = config
