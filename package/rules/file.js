const { dirname } = require("path")
const {
  additional_paths: additionalPaths,
  source_path: sourcePath
} = require("../config")

module.exports = {
  test: /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|eot|otf|ttf|woff|woff2|svg)$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  type: "asset/resource",
  generator: {
    filename: (pathData) => {
      const path = dirname(pathData.filename)
      const stripPaths = [...additionalPaths, sourcePath]

      const selectedStripPath = stripPaths.find((includePath) =>
        path.startsWith(includePath)
      )

      const folders = path
        .replace(`${selectedStripPath}`, "")
        .split("/")
        .filter(Boolean)

      const foldersWithStatic = ["static", ...folders].join("/")
      return `${foldersWithStatic}/[name]-[hash][ext][query]`
    }
  }
}
