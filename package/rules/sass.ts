/* eslint global-require: 0 */

import { getStyleRule } from "../utils/getStyleRule"
import { canProcess, packageMajorVersion } from "../utils/helpers"
import config from "../config"
const extraPaths = config.additional_paths

export default canProcess("sass-loader", (resolvedPath: string) => {
  const optionKey =
    parseInt(packageMajorVersion("sass-loader"), 10) > 15
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
