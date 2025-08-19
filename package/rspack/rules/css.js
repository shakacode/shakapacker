const { rspack } = require("@rspack/core")
const { inliningCss } = require("../../utils/inliningCss")
const { moduleExists } = require("../../utils/helpers")

// Simple CSS rule for rspack - don't use getStyleRule to avoid complexity
module.exports = moduleExists("css-loader") ? {
  test: /\.(css)$/i,
  use: [
    inliningCss ? "style-loader" : rspack.CssExtractRspackPlugin.loader,
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