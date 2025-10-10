/* eslint global-require: 0 */

const { getStyleRule } = require("../utils/getStyleRule")
const { canProcess, packageMajorVersion } = require("../utils/helpers")
const { additional_paths: extraPaths } = require("../config")

export = canProcess("sass-loader", (resolvedPath: string) => {
  const optionKey =
    parseInt(packageMajorVersion("sass-loader"), 10) >= 16
      ? "loadPaths"
      : "includePaths"
  return getStyleRule(/\.(scss|sass)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        sourceMap: true,
        sassOptions: {
          [optionKey]: extraPaths,
          quietDeps: true
        }
      }
    }
  ])
})
