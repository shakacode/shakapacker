const { rspack } = require("@rspack/core")
const { getStyleRule } = require("../../utils/getStyleRule")
const inliningCss = require("../../utils/inliningCss")

const { CssExtractRspackPlugin } = rspack

const sassLoader = {
  loader: "sass-loader",
  options: {
    sourceMap: true,
    sassOptions: {
      quietDeps: true
    }
  }
}

// getStyleRule handles css-loader and postcss-loader internally
// We only need to pass the extraction loader and sass-loader
module.exports = getStyleRule(/\.(scss|sass)$/i, [
  inliningCss ? "style-loader" : CssExtractRspackPlugin.loader,
  sassLoader
])
