/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const { existsSync, readdirSync } = require("fs")
const { basename, dirname, join, relative, resolve } = require("path")
const extname = require("path-complete-extname")
// Use rspack-manifest-plugin for rspack compatibility
const { RspackManifestPlugin } = require("rspack-manifest-plugin")
const { rspack } = require("@rspack/core")
const rules = require("../rules")
const config = require("../../config")
const { isProduction } = require("../../env")
const { moduleExists } = require("../../utils/helpers")

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
      fileName: config.manifestPath.split('/').pop(), // Get just the filename
      publicPath: config.publicPathWithoutCDN,
      writeToFileEmit: true,
      // rspack-manifest-plugin uses different option names than webpack-assets-manifest
      generate: (seed, files, entrypoints) => {
        const manifest = seed || {}
        
        // Add files mapping first
        files.forEach(file => {
          manifest[file.name] = file.path
        })
        
        // Add entrypoints information in webpack-assets-manifest compatible format
        const entrypointsManifest = {}
        for (const [entrypointName, entrypointFiles] of Object.entries(entrypoints)) {
          // rspack-manifest-plugin provides files as arrays, not objects with js/css properties
          const jsFiles = entrypointFiles.filter(file => file.endsWith('.js'))
          const cssFiles = entrypointFiles.filter(file => file.endsWith('.css'))
          
          // Convert to manifest keys (like webpack-assets-manifest does)
          const jsManifestKeys = jsFiles.map(file => {
            // Try exact match first, then try without directory prefix
            const manifestKey = manifest[file] ? file : file.split('/').pop()
            return manifestKey
          })
          const cssManifestKeys = cssFiles.map(file => {
            // Try exact match first, then try without directory prefix  
            const manifestKey = manifest[file] ? file : file.split('/').pop()
            return manifestKey
          })
          
          entrypointsManifest[entrypointName] = {
            assets: {
              js: jsManifestKeys,
              css: cssManifestKeys
            }
          }
        }
        manifest.entrypoints = entrypointsManifest
        
        return manifest
      }
    })
  ]

  if (moduleExists("css-loader")) {
    const hash = isProduction || config.useContentHash ? "-[contenthash:8]" : ""
    // Use Rspack's built-in CSS extraction
    const { CssExtractRspackPlugin } = rspack
    plugins.push(
      new CssExtractRspackPlugin({
        filename: `css/[name]${hash}.css`,
        chunkFilename: `css/[id]${hash}.css`,
        // For projects where css ordering has been mitigated through consistent use of scoping or naming conventions,
        // the css order warnings can be disabled by setting the ignoreOrder flag.
        ignoreOrder: config.css_extract_ignore_order_warnings,
        // Force writing CSS files to disk in development for Rails compatibility
        emit: true
      })
    )
  }

  // Note: Rspack has built-in SRI support, may need adjustment for webpack-subresource-integrity compatibility
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
    rules
  }
}