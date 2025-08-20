const path = require("path")
const { rspack } = require("@rspack/core")
const { canProcess } = require("../../utils/helpers")
const { getStyleRule } = require("../../utils/getStyleRule")
const inliningCss = require("../../utils/inliningCss")

const {
  additional_paths: paths,
  source_path: sourcePath
} = require("../../config")

// getStyleRule handles css-loader and postcss-loader internally
// We only need to pass the extraction loader and less-loader
module.exports = canProcess("less-loader", (resolvedPath) =>
  getStyleRule(/\.(less)(\.erb)?$/i, [
    inliningCss ? "style-loader" : rspack.CssExtractRspackPlugin.loader,
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
