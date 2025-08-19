const { rspack } = require("@rspack/core")
const { canProcess } = require("../../utils/helpers")
const getStyleRule = require("../../utils/getStyleRule")
const { inliningCss } = require("../../utils/inliningCss")

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

module.exports = canProcess("stylus-loader", (resolvedPath) =>
  getStyleRule(/\.(styl)(\.erb)?$/i, [
    inliningCss ? "style-loader" : rspack.CssExtractRspackPlugin.loader,
    cssLoader,
    postcssLoader,
    {
      loader: resolvedPath,
      options: {
        sourceMap: true
      }
    }
  ])
)