import { canProcess } from "../utils/helpers"
import { getStyleRule } from "../utils/getStyleRule"

import config from "../config"
const paths = config.additional_paths
const sourcePath = config.source_path

export default canProcess("stylus-loader", (resolvedPath: string) =>
  getStyleRule(/\.(styl(us)?)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        stylusOptions: {
          // Additional paths for Stylus imports (node_modules is resolved automatically)
          include: [sourcePath, ...paths]
        },
        sourceMap: true
      }
    }
  ])
)
