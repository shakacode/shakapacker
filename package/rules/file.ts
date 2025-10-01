import { dirname, sep, normalize } from "path"
const {
  additional_paths: additionalPaths,
  source_path: sourcePath
} = require("../config")

export = {
  test: /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|eot|otf|ttf|woff|woff2|svg)$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  type: "asset/resource",
  generator: {
    filename: (pathData: { filename: string }) => {
      const path = normalize(dirname(pathData.filename))
      const stripPaths = [...additionalPaths, sourcePath].map((p: string) =>
        normalize(p)
      )

      const selectedStripPath = stripPaths.find((includePath: string) =>
        path.startsWith(includePath)
      )

      if (!selectedStripPath) {
        return `static/[name]-[hash][ext][query]`
      }

      const folders = path
        .replace(selectedStripPath, "")
        .split(sep)
        .filter(Boolean)

      const foldersWithStatic = ["static", ...folders].join("/")
      return `${foldersWithStatic}/[name]-[hash][ext][query]`
    }
  }
}
