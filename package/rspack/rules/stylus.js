const { rspack } = require("@rspack/core")
const { canProcess } = require("../../utils/helpers")
const { getStyleRule } = require("../../utils/getStyleRule")
const inliningCss = require("../../utils/inliningCss")

// getStyleRule handles css-loader and postcss-loader internally
// We only need to pass the extraction loader and stylus-loader
module.exports = canProcess("stylus-loader", (resolvedPath) =>
  getStyleRule(/\.(styl)(\.erb)?$/i, [
    inliningCss ? "style-loader" : rspack.CssExtractRspackPlugin.loader,
    {
      loader: resolvedPath,
      options: {
        sourceMap: true
      }
    }
  ])
)