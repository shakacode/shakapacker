/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const { resolve } = require("path")
const { existsSync } = require("fs")
const { merge } = require("webpack-merge")

const isJsxFile = (filename) => !!filename.match(/\.(jsx|tsx)?(\.erb)?$/)

const isTypescriptFile = (filename) => !!filename.match(/\.(ts|tsx)?(\.erb)?$/)

const getCustomConfig = () => {
  const path = resolve("config", "swc.config.js")
  if (existsSync(path)) {
    return require(path)
  }
  return {}
}

const getSwcLoaderConfig = (filenameToProcess) => {
  const customConfig = getCustomConfig()
  const defaultConfig = {
    loader: require.resolve("swc-loader"),
    options: {
      jsc: {
        parser: {
          dynamicImport: true,
          syntax: isTypescriptFile(filenameToProcess)
            ? "typescript"
            : "ecmascript",
          [isTypescriptFile(filenameToProcess) ? "tsx" : "jsx"]:
            isJsxFile(filenameToProcess)
        },
        loose: true
      },
      sourceMaps: true,
      env: {
        coreJs: 3,
        exclude: ["transform-typeof-symbol"],
        mode: "entry"
      }
    }
  }

  return merge(defaultConfig, customConfig)
}

module.exports = {
  getSwcLoaderConfig
}
