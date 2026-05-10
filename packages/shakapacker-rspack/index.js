// Thin wrapper around the core `shakapacker/rspack` entrypoint. The value of
// this package is in its tighter peer-dependency declarations (see
// packages/shakapacker-rspack/package.json), not the runtime surface.
//
// The compiled core is built by the upstream `shakapacker` package's
// `prepublishOnly`; for local monorepo development run `yarn build` in the
// repository root before consuming this package against the source tree.

// Keep this string in sync with packages/shakapacker-webpack/index.js.
// Both packages emit the same warning code; a regression test asserts they
// match (test/packages/warning-codes.test.js).
const BUNDLER_MISMATCH_CODE = "SHAKAPACKER_BUNDLER_MISMATCH"

// Read config through the explicit `shakapacker/package/config` subpath
// export, which loads the YAML config without pulling in webpack/rspack
// rule modules. This lets the bundler-mismatch preflight run even when
// the root `shakapacker` export (which transitively touches bundler
// peers) fails to load. Falls back to `require("shakapacker").config` for
// older core versions that predate the explicit subpath export, then to
// `undefined` if both fail.
const readShakapackerConfig = () => {
  try {
    // eslint-disable-next-line global-require
    return require("shakapacker/package/config")
  } catch {
    try {
      // eslint-disable-next-line global-require
      return require("shakapacker")?.config
    } catch {
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
    { code: BUNDLER_MISMATCH_CODE }
  )
}

module.exports = require("shakapacker/rspack")
