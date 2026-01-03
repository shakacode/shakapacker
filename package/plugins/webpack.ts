import type { Config } from "../types"

const { requireOrError } = require("../utils/requireOrError")
// TODO: Change to `const { WebpackAssetsManifest }` when dropping 'webpack-assets-manifest < 6.0.0' (Node >=20.10.0) support
const WebpackAssetsManifest = requireOrError("webpack-assets-manifest")
const webpack = requireOrError("webpack")
const config = require("../config") as Config
const { isProduction } = require("../env")
const { moduleExists } = require("../utils/helpers")

/**
 * Allowlist of environment variables that are safe to expose to client-side JavaScript.
 *
 * SECURITY: Never add sensitive variables like DATABASE_URL, API keys, or secrets.
 * These values are embedded directly into the JavaScript bundle and are publicly visible.
 *
 * Users can extend this list via SHAKAPACKER_ENV_VARS environment variable (comma-separated)
 * or by customizing their webpack config.
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
 * Returns an object with variable names as keys and their values (or undefined as default).
 */
const getFilteredEnv = (): Record<string, string | undefined> => {
  const allowedVars = getAllowedEnvVars()
  const filtered: Record<string, string | undefined> = {}

  for (const varName of allowedVars) {
    // Use undefined as default so webpack throws if var is missing and used
    filtered[varName] = process.env[varName]
  }

  return filtered
}

const getPlugins = (): unknown[] => {
  // TODO: Remove WebpackAssetsManifestConstructor workaround when dropping 'webpack-assets-manifest < 6.0.0' (Node >=20.10.0) support
  const WebpackAssetsManifestConstructor =
    "WebpackAssetsManifest" in WebpackAssetsManifest
      ? WebpackAssetsManifest.WebpackAssetsManifest
      : WebpackAssetsManifest
  const plugins = [
    // SECURITY: Only expose allowlisted environment variables to prevent secrets leaking
    // into client-side bundles. See: https://github.com/shakacode/shakapacker/security/advisories
    new webpack.EnvironmentPlugin(getFilteredEnv()),
    new WebpackAssetsManifestConstructor({
      merge: true,
      entrypoints: true,
      writeToDisk: true,
      output: config.manifestPath,
      entrypointsUseAssets: true,
      publicPath: config.publicPathWithoutCDN,
      ...(config.integrity
        ? {
            integrity: config.integrity.enabled,
            integrityHashes: config.integrity.hash_functions
          }
        : {})
    })
  ]

  if (moduleExists("css-loader") && moduleExists("mini-css-extract-plugin")) {
    const hash = isProduction || config.useContentHash ? "-[contenthash:8]" : ""
    const MiniCssExtractPlugin = requireOrError("mini-css-extract-plugin")
    plugins.push(
      new MiniCssExtractPlugin({
        filename: `css/[name]${hash}.css`,
        chunkFilename: `css/[id]${hash}.css`,
        // For projects where css ordering has been mitigated through consistent use of scoping or naming conventions,
        // the css order warnings can be disabled by setting the ignoreOrder flag.
        ignoreOrder: config.css_extract_ignore_order_warnings
      })
    )
  }

  if (
    config.integrity?.enabled &&
    moduleExists("webpack-subresource-integrity")
  ) {
    const SubresourceIntegrityPlugin = requireOrError(
      "webpack-subresource-integrity"
    )
    plugins.push(
      new SubresourceIntegrityPlugin({
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
