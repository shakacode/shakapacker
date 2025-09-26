const { existsSync, readFileSync } = require("fs")
const { requireOrError } = require("../utils/requireOrError")

const { RspackManifestPlugin } = requireOrError("rspack-manifest-plugin")
const rspack = requireOrError("@rspack/core")
const config = require("../config")
const { isProduction } = require("../env")
const { moduleExists } = require("../utils/helpers")

const getPlugins = () => {
  const plugins = [
    new rspack.EnvironmentPlugin(process.env),
    new RspackManifestPlugin({
      fileName: config.manifestPath.split("/").pop(), // Get just the filename
      publicPath: config.publicPathWithoutCDN,
      writeToFileEmit: true,
      // rspack-manifest-plugin uses different option names than webpack-assets-manifest
      generate: (seed, files, entrypoints) => {
        let manifest = seed || {}

        // Load existing manifest if it exists to handle concurrent builds
        try {
          if (existsSync(config.manifestPath)) {
            const existingContent = readFileSync(config.manifestPath, "utf8")
            const parsed = JSON.parse(existingContent)
            if (parsed && typeof parsed === "object") {
              manifest = {
                ...manifest,
                ...parsed
              }
            }
          }
        } catch (error) {
          // eslint-disable-next-line no-console
          console.warn(
            "[SHAKAPACKER]: Warning: Could not read existing manifest.json:",
            String(error)
          )
        }

        // Add files mapping first
        files.forEach((file) => {
          manifest[file.name] = file.path
        })

        // Add entrypoints information compatible with Shakapacker expectations
        const entrypointsManifest = {}
        Object.entries(entrypoints).forEach(
          ([entrypointName, entrypointFiles]) => {
            const jsFiles = entrypointFiles
              .filter(
                (file) => file.endsWith(".js") && !file.includes(".hot-update.")
              )
              .map((file) => config.publicPathWithoutCDN + file)
            const cssFiles = entrypointFiles
              .filter(
                (file) =>
                  file.endsWith(".css") && !file.includes(".hot-update.")
              )
              .map((file) => config.publicPathWithoutCDN + file)

            entrypointsManifest[entrypointName] = {
              assets: {
                js: jsFiles,
                css: cssFiles
              }
            }
          }
        )
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

  // Use Rspack's built-in SubresourceIntegrityPlugin
  if (config.integrity.enabled) {
    plugins.push(
      new rspack.SubresourceIntegrityPlugin({
        hashFuncNames: config.integrity.hash_functions,
        enabled: isProduction
      })
    )
  }

  return plugins
}

module.exports = {
  getPlugins
}
