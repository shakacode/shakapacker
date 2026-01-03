import type { Config } from "../types"

const { requireOrError } = require("../utils/requireOrError")

const { RspackManifestPlugin } = requireOrError("rspack-manifest-plugin")
const rspack = requireOrError("@rspack/core")
const config = require("../config") as Config
const { isProduction } = require("../env")
const { moduleExists } = require("../utils/helpers")

interface ManifestFile {
  name: string
  path: string
}

interface EntrypointAssets {
  js: string[]
  css: string[]
}

interface Manifest {
  entrypoints?: Record<string, { assets: EntrypointAssets }>
  [key: string]:
    | string
    | { assets: EntrypointAssets }
    | Record<string, { assets: EntrypointAssets }>
    | undefined
}

/**
 * Allowlist of environment variables that are safe to expose to client-side JavaScript.
 *
 * SECURITY: Never add sensitive variables like DATABASE_URL, API keys, or secrets.
 * These values are embedded directly into the JavaScript bundle and are publicly visible.
 *
 * Users can extend this list via SHAKAPACKER_ENV_VARS environment variable (comma-separated)
 * or by customizing their rspack config.
 */
const DEFAULT_ALLOWED_ENV_VARS = [
  "NODE_ENV",
  "RAILS_ENV",
  "WEBPACK_SERVE"
] as const

/**
 * Pattern to detect potentially sensitive environment variable names.
 * Used to warn developers if they accidentally expose secrets via SHAKAPACKER_ENV_VARS.
 */
const DANGEROUS_PATTERNS =
  /SECRET|PASSWORD|KEY|TOKEN|CREDENTIAL|DATABASE_URL|AWS_|PRIVATE|AUTH/i

/**
 * Gets the list of environment variables to expose to client-side code.
 * Combines default allowed vars with any user-specified vars from SHAKAPACKER_ENV_VARS.
 */
const getAllowedEnvVars = (): string[] => {
  const allowed: string[] = [...DEFAULT_ALLOWED_ENV_VARS]

  // Allow users to specify additional env vars via SHAKAPACKER_ENV_VARS
  const userVars = process.env.SHAKAPACKER_ENV_VARS
  if (userVars) {
    const additionalVars = userVars
      .split(",")
      .map((v) => v.trim())
      .filter(Boolean)

    // Warn about potentially dangerous variable names
    additionalVars.forEach((varName) => {
      if (DANGEROUS_PATTERNS.test(varName)) {
        console.warn(
          `⚠️  [SHAKAPACKER SECURITY WARNING] "${varName}" matches a sensitive pattern. ` +
            `Ensure this variable is safe to expose in client-side JavaScript bundles.`
        )
      }
    })

    allowed.push(...additionalVars)
  }

  return allowed
}

/**
 * Builds a filtered environment object containing only allowed variables.
 * Returns an object with variable names as keys and their values.
 * Uses null as default for missing variables (rspack treats null as optional).
 */
const getFilteredEnv = (): Record<string, string | null> => {
  const allowedVars = getAllowedEnvVars()
  const filtered: Record<string, string | null> = {}

  for (const varName of allowedVars) {
    // Use null as default for missing vars - rspack treats null as optional
    // (undefined would cause rspack to throw if the var is used but not set)
    filtered[varName] = process.env[varName] ?? null
  }

  return filtered
}

const getPlugins = (): unknown[] => {
  const plugins = [
    // SECURITY: Only expose allowlisted environment variables to prevent secrets leaking
    // into client-side bundles. See: https://github.com/shakacode/shakapacker/security/advisories
    new rspack.EnvironmentPlugin(getFilteredEnv()),
    new RspackManifestPlugin({
      fileName: config.manifestPath.split("/").pop(), // Get just the filename
      publicPath: config.publicPathWithoutCDN,
      writeToFileEmit: true,
      // rspack-manifest-plugin uses different option names than webpack-assets-manifest
      generate: (
        seed: Manifest | null,
        files: ManifestFile[],
        entrypoints: Record<string, string[]>
      ) => {
        const manifest: Manifest = seed || {}

        // Add files mapping first
        files.forEach((file) => {
          manifest[file.name] = file.path
        })

        // Add entrypoints information compatible with Shakapacker expectations
        const entrypointsManifest: Record<
          string,
          { assets: EntrypointAssets }
        > = {}
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
  if (config.integrity?.enabled) {
    plugins.push(
      new rspack.SubresourceIntegrityPlugin({
        hashFuncNames: config.integrity.hash_functions,
        enabled: isProduction
      })
    )
  }

  return plugins
}

export = {
  getPlugins
}
