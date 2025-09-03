/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const { existsSync, readdirSync } = require("fs")
const { basename, dirname, join, relative, resolve } = require("path")
const extname = require("path-complete-extname")
const { RspackManifestPlugin } = require("rspack-manifest-plugin")
const rspack = require("@rspack/core")
const rules = require("../rules")
const config = require("../config")
const { isProduction } = require("../env")
const { moduleExists } = require("../utils/helpers")

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

const getPlugins = () => {
  const plugins = [
    new rspack.EnvironmentPlugin(process.env),
    new RspackManifestPlugin({
      fileName: config.manifestPath.split("/").pop(), // Get just the filename
      publicPath: config.publicPathWithoutCDN,
      useEntryKeys: true,
      writeToFileEmit: true,
      // rspack-manifest-plugin uses different option names than webpack-assets-manifest
      generate: (seed, files, entrypoints) => {
        const manifest = seed || {}

        // Add files mapping first
        files.forEach((file) => {
          manifest[file.name] = file.path
        })

        // Add entrypoints information compatible with Shakapacker expectations
        const entrypointsManifest = {}
        Object.entries(entrypoints).forEach(
          ([entrypointName, entrypointFiles]) => {
            const jsFiles = entrypointFiles.filter((file) =>
              file.endsWith(".js")
            )
            const cssFiles = entrypointFiles.filter((file) =>
              file.endsWith(".css")
            )

            // Helper function to resolve file paths consistently
            const resolveFilePath = (file) => {
              // Try exact match first
              if (manifest[file]) return manifest[file]

              // Try filename only
              const filename = file.split("/").pop()
              if (manifest[filename]) return manifest[filename]

              // For hashed files, try to find the base name without hash
              // e.g., "css/org-350a7e61.css" -> "org.css"
              const baseMatch = filename.match(/^(.+?)-[a-f0-9]+(\.\w+)$/)
              if (baseMatch) {
                const baseName = baseMatch[1] + baseMatch[2] // "org.css"
                if (manifest[baseName]) return manifest[baseName]
              }

              // For webpack chunk files with full directory path
              // e.g., "js/598-7f94a9abddc251f3.js" -> "js/598-js"
              const chunkMatch = file.match(
                /^(.+\/)?(\d+)-[a-f0-9]+\.(js|css)$/
              )
              if (chunkMatch) {
                const [, dir = "", chunkNum, ext] = chunkMatch
                const chunkKey = `${dir}${chunkNum}-${ext}` // "js/598-js"
                if (manifest[chunkKey]) return manifest[chunkKey]
              }

              // Fallback to original file path
              return file
            }

            entrypointsManifest[entrypointName] = {
              assets: {
                js: jsFiles.map(resolveFilePath),
                css: cssFiles.map(resolveFilePath)
              }
            }
          }
        )
        manifest.entrypoints = entrypointsManifest

        return manifest
      },
      serialize: (manifest) => {
        // Load existing manifest if it exists to handle concurrent builds
        let existingManifest = {};

        try {
          if (fs.existsSync(config.manifestPath)) {
            const existingContent = fs.readFileSync(config.manifestPath, 'utf8');
            const parsed = JSON.parse(existingContent);
            existingManifest = parsed && typeof parsed === 'object' ? parsed : {};
          }
        } catch (error) {
          console.warn('Warning: Could not read existing manifest.json:', String(error));
        }

        const mergedManifest = { ...existingManifest, ...manifest };

        return JSON.stringify(mergedManifest, Object.keys(mergedManifest).sort(), 2);
      }
    })
  ]

  if (moduleExists("css-loader") && moduleExists("mini-css-extract-plugin")) {
    const hash = isProduction || config.useContentHash ? "-[contenthash:8]" : ""
    const MiniCssExtractPlugin = require("mini-css-extract-plugin")
    plugins.push(
      new MiniCssExtractPlugin({
        filename: `css/[name]${hash}.css`,
        chunkFilename: `css/[id]${hash}.css`,
        // For projects where css ordering has been mitigated through consistent use of scoping or naming conventions,
        // the css order warnings can be disabled by setting the ignoreOrder flag.
        // Read: https://stackoverflow.com/questions/51971857/mini-css-extract-plugin-warning-in-chunk-chunkname-mini-css-extract-plugin-con
        ignoreOrder: config.css_extract_ignore_order_warnings
      })
    )
  }

  if (
    moduleExists("webpack-subresource-integrity") &&
    config.integrity.enabled
  ) {
    const {
      SubresourceIntegrityPlugin
    } = require("webpack-subresource-integrity")

    plugins.push(
      new SubresourceIntegrityPlugin({
        hashFuncNames: config.integrity.hash_functions,
        enabled: isProduction
      })
    )
  }

  return plugins
}

// Don't use contentHash except for production for performance
// https://webpack.js.org/guides/build-performance/#avoid-production-specific-tooling
const hash = isProduction || config.useContentHash ? "-[contenthash]" : ""

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
    strictExportPresence: true,
    rules
  }
}
