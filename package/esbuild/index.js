/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const { resolve } = require("path")
const { existsSync } = require("fs")
const { merge } = require("webpack-merge")

const getLoaderExtension = (filename) => {
  const matchData = filename.match(/\.([jt]sx?)?(\.erb)?$/)

  if (!matchData) {
    return "js"
  }

  return matchData[1]
}

const getCustomConfig = () => {
  const path = resolve("config", "esbuild.config.js")
  if (existsSync(path)) {
    return require(path)
  }
  return {}
}

const getEsbuildLoaderConfig = (filenameToProcess) => {
  const customConfig = getCustomConfig()
  const defaultConfig = {
    loader: require.resolve("esbuild-loader"),
    options: {
      loader: getLoaderExtension(filenameToProcess)
    }
  }

  return merge(defaultConfig, customConfig)
}

module.exports = {
  getEsbuildLoaderConfig
}
