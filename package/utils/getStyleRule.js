/* eslint global-require: 0 */
const { canProcess, moduleExists } = require("./helpers")
const { requireOrError } = require("./requireOrError")
const config = require("../config")
const inliningCss = require("./inliningCss")

const getStyleRule = (test, preprocessors = []) => {
  if (moduleExists("css-loader")) {
    const tryPostcss = () =>
      canProcess("postcss-loader", (loaderPath) => ({
        loader: loaderPath,
        options: { sourceMap: true }
      }))

    // style-loader is required when using css modules with HMR on the webpack-dev-server

    const extractionPlugin =
      config.bundle === "rspack"
        ? requireOrError("@rspack/core").CssExtractRspackPlugin.loader
        : requireOrError("mini-css-extract-plugin").loader

    const use = [
      inliningCss ? "style-loader" : extractionPlugin,
      {
        loader: require.resolve("css-loader"),
        options: {
          sourceMap: true,
          importLoaders: 2,
          modules: {
            auto: true
          }
        }
      },
      tryPostcss(),
      ...preprocessors
    ].filter(Boolean)

    const result = {
      test,
      use
    }

    if (config.bundle === "rspack") {
      result.type = "javascript/auto" // Required for rspack CSS extraction
    }

    return result
  }

  return null
}

module.exports = { getStyleRule }
