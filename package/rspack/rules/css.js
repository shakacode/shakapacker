const { rspack } = require("@rspack/core")
const inliningCss = require("../../utils/inliningCss")
const { moduleExists } = require("../../utils/helpers")

const { CssExtractRspackPlugin } = rspack

// Simple CSS rule for rspack - don't use getStyleRule to avoid complexity
module.exports = moduleExists("css-loader") ? {
  test: /\.(css)$/i,
  type: 'javascript/auto',
  use: [
    inliningCss ? "style-loader" : CssExtractRspackPlugin.loader,
    {
      loader: "css-loader",
      options: {
        sourceMap: true,
        importLoaders: 1,
        modules: false
      }
    }
  ]
} : null