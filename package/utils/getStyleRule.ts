/* eslint global-require: 0 */
import { canProcess, moduleExists } from "./helpers"
import requireOrError from "./requireOrError"
import config from "../config"
import inliningCss from "./inliningCss"

export interface StyleRule {
  test: RegExp
  use: unknown[]
  type?: string
}

interface RspackCore {
  CssExtractRspackPlugin: {
    loader: string
  }
}

interface MiniCssExtractPlugin {
  loader: string
}

const getStyleRule = (
  test: RegExp,
  preprocessors: unknown[] = []
): StyleRule | null => {
  if (moduleExists("css-loader")) {
    const tryPostcss = () =>
      canProcess("postcss-loader", (loaderPath: string) => ({
        loader: loaderPath,
        options: { sourceMap: true }
      }))

    // style-loader is required when using css modules with HMR on the webpack-dev-server

    const extractionPlugin =
      config.assets_bundler === "rspack"
        ? (requireOrError("@rspack/core")).CssExtractRspackPlugin
            .loader
        : (requireOrError("mini-css-extract-plugin"))
            .loader

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
            exportLocalsConvention: "camelCaseOnly"
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

export { getStyleRule }
