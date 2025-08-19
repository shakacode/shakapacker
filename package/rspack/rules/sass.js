const { rspack } = require("@rspack/core")
const { getStyleRule } = require("../../utils/getStyleRule")
const { isProduction } = require("../../env")
const { inliningCss } = require("../../utils/inliningCss")

const sassLoader = {
  loader: "sass-loader",
  options: {
    sourceMap: true
  }
}

const postcssLoader = {
  loader: "postcss-loader",
  options: {
    sourceMap: true
  }
}

const cssLoader = {
  loader: "css-loader",
  options: {
    sourceMap: true,
    importLoaders: 2,
    modules: false
  }
}

module.exports = getStyleRule(/\.(scss|sass)$/i, [
  inliningCss ? "style-loader" : rspack.CssExtractRspackPlugin.loader,
  cssLoader,
  postcssLoader,
  sassLoader
])