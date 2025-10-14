import { canProcess } from "../utils/helpers"
import { getStyleRule } from "../utils/getStyleRule"
import config from "../config"

const { additional_paths: paths, source_path: sourcePath } = config

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
