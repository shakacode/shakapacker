// Thin wrapper around the core `shakapacker/rspack` entrypoint. The value of
// this package is in its tighter peer-dependency declarations (see
// packages/shakapacker-rspack/package.json), not the runtime surface.
//
// The compiled core is built by the upstream `shakapacker` package's
// `prepublishOnly`; for local monorepo development run `yarn build` in the
// repository root before consuming this package against the source tree.

const readShakapackerConfig = () => {
  try {
    // Read the config subpath first so a webpack-default app missing webpack
    // peers can still get the bundler mismatch warning before root export load.
    // eslint-disable-next-line global-require
    return require("shakapacker/package/config")
  } catch {
    try {
      // eslint-disable-next-line global-require
      return require("shakapacker")?.config
    } catch {
      // If shakapacker itself cannot load, the actual export below should
      // surface that original error. There is no reliable config to inspect.
      return undefined
    }
  }
}

const shakapackerConfig = readShakapackerConfig()
const bundlerSetting = shakapackerConfig?.assets_bundler

// Detect the misconfiguration where shakapacker-rspack is installed but the
// app is configured to use webpack (or left unset, which defaults to webpack).
// The rspack entrypoint always loads rspack-specific rules/plugins, so the
// warning points users at the config change before they hit downstream module
// resolution errors.
const effectiveBundler = bundlerSetting ?? "webpack"
if (shakapackerConfig !== undefined && effectiveBundler !== "rspack") {
  const bundlerDescription =
    bundlerSetting === undefined
      ? 'unset, which defaults to "webpack"'
      : `"${bundlerSetting}"`

  process.emitWarning(
    `[shakapacker-rspack] config.assets_bundler is ${bundlerDescription} but this package only supports rspack.\n` +
      `Install shakapacker-webpack and require it instead, or set \`assets_bundler: rspack\` in config/shakapacker.yml.`,
    { code: "SHAKAPACKER_BUNDLER_MISMATCH" }
  )
}

module.exports = require("shakapacker/rspack")
