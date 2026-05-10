// Thin wrapper around the core `shakapacker/rspack` entrypoint. The value of
// this package is in its tighter peer-dependency declarations (see
// packages/shakapacker-rspack/package.json), not the runtime surface.
//
// The compiled core is built by the upstream `shakapacker` package's
// `prepublishOnly`; for local monorepo development run `yarn build` in the
// repository root before consuming this package against the source tree.

// `shakapacker/package/config` is currently exposed only via core's
// wildcard subpath export (`"./package/*": "./package/*"` in the
// `shakapacker` package.json), not as a curated public entry. We rely on
// it because it loads the YAML config without pulling in webpack/rspack
// rule modules — which lets this preflight check run even when the root
// export (which transitively touches bundler peers) fails to load.
//
// Tradeoff: any v11 reorganization of the `package/` directory (the RFC
// proposes a monorepo split that moves core under `packages/shakapacker/`)
// could break this require. The fallback to `require("shakapacker")?.config`
// still yields a usable config for the bundler-mismatch check; if both
// throw, we silently return undefined and let the final
// `require("shakapacker/rspack")` surface the real error. When core
// stabilizes a public `shakapacker/config` export, switch this away from
// the wildcard subpath.
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
    { code: "SHAKAPACKER_BUNDLER_MISMATCH" }
  )
}

module.exports = require("shakapacker/rspack")
