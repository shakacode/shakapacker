/* eslint global-require: 0 */

const getStyleRule = require("../utils/getStyleRule")
const { canProcess, packageMajorVersion } = require("../utils/helpers")
const { additional_paths: extraPaths } = require("../config")

module.exports = canProcess("sass-loader", (resolvedPath) => {
  const optionKey =
    packageMajorVersion("sass-loader") > 15 ? "loadPaths" : "includePaths"
  return getStyleRule(/\.(scss|sass)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        sassOptions: { [optionKey]: extraPaths }
      }
    }
  ])
})
