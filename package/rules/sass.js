/* eslint global-require: 0 */

const getStyleRule = require("../utils/getStyleRule")
const { canProcess } = require("../utils/helpers")
const { additional_paths: includePaths } = require("../config")

module.exports = canProcess("sass-loader", (resolvedPath) =>
  getStyleRule(/\.(scss|sass)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        sassOptions: { includePaths }
      }
    }
  ])
)
