/* eslint global-require: 0 */
const { canProcess, moduleExists } = require("./helpers")
const { requireOrError } = require("./requireOrError")
const config = require("../config")
const inliningCss = require("./inliningCss")

interface StyleRule {
  test: RegExp
  use: any[]
  type?: string
}

const getStyleRule = (test: RegExp, preprocessors: any[] = []): StyleRule | null => {
  if (moduleExists("css-loader")) {
    const tryPostcss = () =>
      canProcess("postcss-loader", (loaderPath: string) => ({
        loader: loaderPath,
        options: { sourceMap: true }
      }))

    // style-loader is required when using css modules with HMR on the webpack-dev-server

    const extractionPlugin =
      config.assets_bundler === "rspack"
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
            auto: true,
            // v9 defaults: Use named exports with camelCase conversion
            // Note: css-loader requires 'camelCaseOnly' or 'dashesOnly' when namedExport is true
            // Using 'camelCase' with namedExport: true causes a build error
            namedExport: true,
            exportLocalsConvention: 'camelCaseOnly'
          }
        }
      },
      tryPostcss(),
      ...preprocessors
    ].filter(Boolean)

    const result: StyleRule = {
      test,
      use
    }

    if (config.assets_bundler === "rspack") {
      result.type = "javascript/auto"
    }

    return result
  }

  return null
}

export = { getStyleRule }