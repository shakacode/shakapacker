const path = require("path")
const { rspack } = require("@rspack/core")
const { canProcess } = require("../../utils/helpers")
const getStyleRule = require("../../utils/getStyleRule")
const { inliningCss } = require("../../utils/inliningCss")

const {
  additional_paths: paths,
  source_path: sourcePath
} = require("../../config")

const cssLoader = {
  loader: "css-loader",
  options: {
    sourceMap: true,
    importLoaders: 2,
    modules: false
  }
}

const postcssLoader = {
  loader: "postcss-loader",
  options: {
    sourceMap: true
  }
}

module.exports = canProcess("less-loader", (resolvedPath) =>
  getStyleRule(/\.(less)(\.erb)?$/i, [
    inliningCss ? "style-loader" : rspack.CssExtractRspackPlugin.loader,
    cssLoader,
    postcssLoader,
    {
      loader: resolvedPath,
      options: {
        lessOptions: {
          paths: [path.resolve(__dirname, "node_modules"), sourcePath, ...paths]
        },
        sourceMap: true
      }
    }
  ])
)