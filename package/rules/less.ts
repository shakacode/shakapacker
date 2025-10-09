import { canProcess } from "../utils/helpers"
import { getStyleRule } from "../utils/getStyleRule"

import config from "../config"
const paths = config.additional_paths
const sourcePath = config.source_path

export default canProcess("less-loader", (resolvedPath: string) =>
  getStyleRule(/\.(less)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        lessOptions: {
          // Additional paths for Less imports (node_modules is resolved automatically)
          paths: [sourcePath, ...paths]
        },
        sourceMap: true
      }
    }
  ])
)
