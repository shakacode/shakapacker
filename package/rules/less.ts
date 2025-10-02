import { resolve } from "path"
const { canProcess } = require("../utils/helpers")
const { getStyleRule } = require("../utils/getStyleRule")

const {
  additional_paths: paths,
  source_path: sourcePath
} = require("../config")

export = canProcess("less-loader", (resolvedPath: string) =>
  getStyleRule(/\.(less)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        lessOptions: {
          paths: [
            // Resolve to project root node_modules from compiled location (package/rules/)
            resolve(__dirname, "..", "..", "node_modules"),
            sourcePath,
            ...paths
          ]
        },
        sourceMap: true
      }
    }
  ])
)
