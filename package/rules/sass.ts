/* eslint global-require: 0 */

import { getStyleRule } from "../utils/getStyleRule"
import { canProcess, packageMajorVersion } from "../utils/helpers"
import { additional_paths: extraPaths } from "../config"

export = canProcess("sass-loader", (resolvedPath: string) => {
  const optionKey =
    packageMajorVersion("sass-loader") > 15 ? "loadPaths" : "includePaths"
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
