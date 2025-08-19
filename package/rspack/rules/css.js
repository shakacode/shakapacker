const { rspack } = require("@rspack/core")
const { getStyleRule } = require("../../utils/getStyleRule")
const { isProduction } = require("../../env")
const { inliningCss } = require("../../utils/inliningCss")

// Use Rspack's built-in CSS handling
const cssLoader = {
  loader: "css-loader",
  options: {
    sourceMap: true,
    importLoaders: 1,
    modules: false
  }
}

module.exports = getStyleRule(/\.(css)$/i, [
  inliningCss ? "style-loader" : rspack.CssExtractRspackPlugin.loader,
  cssLoader
])