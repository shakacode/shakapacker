/* eslint global-require: 0 */

import { getStyleRule } from "../utils/getStyleRule"
import { canProcess, packageMajorVersion } from "../utils/helpers"
import config from "../config"

const { additional_paths: extraPaths } = config

export default canProcess("sass-loader", (resolvedPath: string) => {
  const optionKey =
    packageMajorVersion("sass-loader") >= 16 ? "loadPaths" : "includePaths"
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
