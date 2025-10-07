import { canProcess } from "../utils/helpers"
import { getStyleRule } from "../utils/getStyleRule"

import { additional_paths: paths,
  source_path: sourcePath } from "../config"

export = canProcess("less-loader", (resolvedPath: string) =>
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
