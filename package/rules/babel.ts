const { loaderMatches, packageMajorVersion } = require("../utils/helpers")
const { isModuleNotFoundError } = require("../utils/errorHelpers")
const { javascript_transpiler: javascriptTranspiler } = require("../config")
const { isProduction } = require("../env")
const jscommon = require("./jscommon")

const babelCoreMajorVersion = (): number => {
  try {
    return packageMajorVersion("@babel/core")
  } catch (error: unknown) {
    if (!isModuleNotFoundError(error)) {
      throw error
    }

    throw new Error(
      "Your Shakapacker config specified using Babel, but @babel/core package is not installed.\n" +
        "\nTo fix this issue, run one of the following commands:\n" +
        "  npm install --save-dev @babel/core\n" +
        "  yarn add --dev @babel/core\n" +
        "\nOr change your 'javascript_transpiler' setting in shakapacker.yml to use a different loader."
    )
  }
}

const validateBabelLoaderCompatibility = (): void => {
  if (
    babelCoreMajorVersion() >= 8 &&
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
    test: /\.(js|jsx|mjs|cjs|ts|tsx|coffee)?(\.erb)?$/,
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
