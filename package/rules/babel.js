const { loaderMatches } = require("../utils/helpers")
const { webpack_loader: webpackLoader } = require("../config")
const { isProduction } = require("../env")
const jscommon = require("./jscommon")

module.exports = loaderMatches(webpackLoader, "babel", () => ({
  test: /\.(js|jsx|mjs|ts|tsx|coffee)?(\.erb)?$/,
  ...jscommon,
  use: [
    {
      loader: require.resolve("babel-loader"),
      options: {
        cacheDirectory: true,
        cacheCompression: isProduction,
        compact: isProduction
      }
    }
  ]
}))
