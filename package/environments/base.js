/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const { basename, dirname, join, relative, resolve } = require("path")
const { existsSync, readdirSync } = require("fs")
const extname = require("path-complete-extname")
const config = require("../config")
const { isProduction } = require("../env")

const pluginsPath = resolve(
  __dirname,
  "..",
  "plugins",
  `${config.assets_bundler}.js`
)
const { getPlugins } = require(pluginsPath)
const rulesPath = resolve(
  __dirname,
  "..",
  "rules",
  `${config.assets_bundler}.js`
)
const rules = require(rulesPath)

// Don't use contentHash except for production for performance
// https://webpack.js.org/guides/build-performance/#avoid-production-specific-tooling
const hash = isProduction || config.useContentHash ? "-[contenthash]" : ""

const getFilesInDirectory = (dir, includeNested) => {
  if (!existsSync(dir)) {
    return []
  }

  return readdirSync(dir, { withFileTypes: true }).flatMap((dirent) => {
    const filePath = join(dir, dirent.name)

    if (dirent.isDirectory() && includeNested) {
      return getFilesInDirectory(filePath, includeNested)
    }
    if (dirent.isFile()) {
      return filePath
    }
    return []
  })
}

const getEntryObject = () => {
  const entries = {}
  const rootPath = join(config.source_path, config.source_entry_path)
  if (config.source_entry_path === "/" && config.nested_entries) {
    throw new Error(
      "Your shakapacker config specified using a source_entry_path of '/' with 'nested_entries' == " +
        "'true'. Doing this would result in packs for every one of your source files"
    )
  }

  getFilesInDirectory(rootPath, config.nested_entries).forEach((path) => {
    const namespace = relative(join(rootPath), dirname(path))
    const name = join(namespace, basename(path, extname(path)))
    let assetPaths = resolve(path)

    // Allows for multiple filetypes per entry (https://webpack.js.org/guides/entry-advanced/)
    // Transforms the config object value to an array with all values under the same name
    let previousPaths = entries[name]
    if (previousPaths) {
      previousPaths = Array.isArray(previousPaths)
        ? previousPaths
        : [previousPaths]
      previousPaths.push(assetPaths)
      assetPaths = previousPaths
    }

    entries[name] = assetPaths
  })

  return entries
}

const getModulePaths = () => {
  const result = [resolve(config.source_path)]

  if (config.additional_paths) {
    config.additional_paths.forEach((path) => result.push(resolve(path)))
  }
  result.push("node_modules")

  return result
}

module.exports = {
  mode: "production",
  output: {
    filename: `js/[name]${hash}.js`,
    chunkFilename: `js/[name]${hash}.chunk.js`,

    // https://webpack.js.org/configuration/output/#outputhotupdatechunkfilename
    hotUpdateChunkFilename: "js/[id].[fullhash].hot-update.js",
    path: config.outputPath,
    publicPath: config.publicPath,

    // This is required for SRI to work.
    crossOriginLoading: config.integrity.enabled
      ? config.integrity.cross_origin
      : false
  },
  entry: getEntryObject(),
  resolve: {
    extensions: [".js", ".jsx", ".mjs", ".ts", ".tsx", ".coffee"],
    modules: getModulePaths()
  },

  plugins: getPlugins(),

  resolveLoader: {
    modules: ["node_modules"]
  },

  optimization: {
    splitChunks: { chunks: "all" },
    runtimeChunk: "single"
  },

  module: {
    rules
  }
}
