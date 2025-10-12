import requireOrError from "../utils/requireOrError"
import config from "../config"
import { moduleExists } from "../utils/helpers"
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { isProduction } = require("../env")

// TODO: Change to `const { WebpackAssetsManifest }` when dropping 'webpack-assets-manifest < 6.0.0' (Node >=20.10.0) support
const WebpackAssetsManifest = requireOrError<
  | { WebpackAssetsManifest: new (options: unknown) => unknown }
  | (new (options: unknown) => unknown)
>("webpack-assets-manifest")
const webpack = requireOrError<{
  EnvironmentPlugin: new (env: NodeJS.ProcessEnv) => unknown
}>("webpack")

const getPlugins = (): unknown[] => {
  // TODO: Remove WebpackAssetsManifestConstructor workaround when dropping 'webpack-assets-manifest < 6.0.0' (Node >=20.10.0) support
  const WebpackAssetsManifestConstructor =
    "WebpackAssetsManifest" in WebpackAssetsManifest
      ? WebpackAssetsManifest.WebpackAssetsManifest
      : WebpackAssetsManifest
  const plugins = [
    new webpack.EnvironmentPlugin(process.env),
    new WebpackAssetsManifestConstructor({
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
    const MiniCssExtractPlugin = requireOrError<
      new (options: unknown) => unknown
    >("mini-css-extract-plugin")
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
    const SubresourceIntegrityPlugin = requireOrError<
      new (options: unknown) => unknown
    >("webpack-subresource-integrity")
    plugins.push(
      new SubresourceIntegrityPlugin({
        hashFuncNames: config.integrity.hash_functions,
        enabled: isProduction
      })
    )
  }

  return plugins
}

export { getPlugins }
