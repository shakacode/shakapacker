const { loaderMatches, packageMajorVersion } = require("../utils/helpers")
const { javascript_transpiler: javascriptTranspiler } = require("../config")
const { isProduction } = require("../env")
const jscommon = require("./jscommon")

const validateBabelLoaderCompatibility = (): void => {
  if (
    packageMajorVersion("@babel/core") >= 8 &&
    packageMajorVersion("babel-loader") < 10
  ) {
    throw new Error(
      "Babel 8 requires babel-loader 10 or newer. " +
        "Install babel-loader@^10 or use @babel/core@^7."
    )
  }
}

export = loaderMatches(javascriptTranspiler, "babel", () => {
  validateBabelLoaderCompatibility()

  return {
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
  }
})
