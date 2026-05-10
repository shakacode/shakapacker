// Thin wrapper around the core `shakapacker` package. The value of this
// package is in its tighter peer-dependency declarations (see
// packages/shakapacker-webpack/package.json), not the runtime surface.
//
// Re-exporting the shakapacker root (rather than a `shakapacker/webpack`
// subpath, which doesn't exist) is intentional: webpack is the default
// codepath in core. shakapacker-rspack/index.js, by contrast, re-exports
// the bundler-specific `shakapacker/rspack` entrypoint.
//
// The compiled core is built by the upstream `shakapacker` package's
// `prepublishOnly`; for local monorepo development run `yarn build` in the
// repository root first.

// Warn when the configured transpiler pair isn't resolvable. The three
// transpiler pairs are keyed by the `javascript_transpiler` value they
// satisfy so the check can be scoped to whichever one the app actually
// uses. Checking "any pair" would silence the warning when, for example,
// an app configured for swc still has Babel leftovers installed — and
// then webpack would fail later with a cryptic loader error.
const transpilerGroups = {
  swc: ["@swc/core", "swc-loader"],
  babel: ["@babel/core", "babel-loader"],
  esbuild: ["esbuild", "esbuild-loader"]
}

// Keep this string in sync with packages/shakapacker-rspack/index.js.
// Both packages emit the same warning code; a regression test asserts they
// match (test/packages/warning-codes.test.js).
const BUNDLER_MISMATCH_CODE = "SHAKAPACKER_BUNDLER_MISMATCH"
const NO_TRANSPILER_CODE = "SHAKAPACKER_NO_TRANSPILER"

// Resolve from the consuming app's working directory rather than from
// inside `node_modules/shakapacker-webpack/`. Webpack itself runs from the
// project root, so peer deps are resolvable from `process.cwd()` even
// under pnpm strict mode and Yarn PnP, where they aren't hoisted into the
// wrapper's own folder. The narrow assumption is that the build process
// invokes Node from the project root; a script that `cd`s elsewhere
// before requiring this package can produce a false-negative warning,
// which we accept as a known limitation in exchange for handling the
// common pnpm/PnP case correctly.
const canResolve = (mod) => {
  try {
    require.resolve(mod, { paths: [process.cwd()] })
    return true
  } catch {
    return false
  }
}

// Read the YAML config via the lightweight `shakapacker/package/config`
// subpath. This avoids triggering core's bundler-specific module loading
// (which transitively requires webpack/rspack peers), so the warnings can
// fire even when `require("shakapacker")` would throw — e.g., a user
// configured `assets_bundler: rspack` but installed shakapacker-webpack
// without @rspack/core. Falls back to `require("shakapacker").config` if
// the subpath isn't available (older core versions or future
// reorganizations); if both fail, the wrapper still emits a generic
// transpiler warning before re-raising the load error from the final
// require below.
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
const shakapackerLoadFailed = shakapackerConfig === undefined
const bundlerSetting = shakapackerConfig?.assets_bundler
const transpilerSetting = shakapackerConfig?.javascript_transpiler

// Detect the misconfiguration where shakapacker-webpack is installed but
// the app is configured to use a non-webpack bundler. Surfacing a
// structured warning is cheaper than the cryptic loader errors that follow
// when the wrong rules/plugins try to load. Skipped when config loading
// failed entirely (we don't know what the user configured) or when the
// bundler is webpack/unset (webpack is the default).
if (
  !shakapackerLoadFailed &&
  bundlerSetting !== undefined &&
  bundlerSetting !== "webpack"
) {
  process.emitWarning(
    `[shakapacker-webpack] config.assets_bundler is "${bundlerSetting}" but this package only supports webpack.\n` +
      `Install shakapacker-rspack and require it instead, or set \`assets_bundler: webpack\` in config/shakapacker.yml.`,
    { code: BUNDLER_MISMATCH_CODE }
  )
}

// Intentionally not gated on `!shakapackerLoadFailed` (unlike the bundler
// mismatch block above): when config loading fails, `transpilerSetting` is
// undefined and we still want the missing-transpiler warning to fire so the
// user isn't silently left with no transpiler. The shakapackerLoadFailed
// branch below shapes the message to surface the load failure first.
if (transpilerSetting !== "none") {
  // When the config names a known transpiler, only that pair counts —
  // unrelated transpilers being installed shouldn't mask a missing peer.
  // When the setting is missing (config load failed) or unrecognized
  // (e.g. "custom"), fall back to "any pair resolves" since we genuinely
  // don't know what the user configured. Defaulting to a specific pair
  // would produce false positives — e.g., the install template ships
  // `javascript_transpiler: "swc"`, so a user with that standard install
  // plus a transient config load failure has SWC installed, not Babel.
  const expectedGroup = transpilerSetting
    ? transpilerGroups[transpilerSetting]
    : null
  const hasExpectedTranspiler = expectedGroup
    ? expectedGroup.every(canResolve)
    : Object.values(transpilerGroups).some((group) => group.every(canResolve))

  if (!hasExpectedTranspiler) {
    // process.emitWarning surfaces through Node's structured warning system —
    // visible by default in stderr (including CI), suppressible with
    // --no-warnings or `process.removeAllListeners("warning")` for users who
    // know what they're doing.
    let message
    if (shakapackerLoadFailed) {
      // When config can't be read, surface the load failure as the
      // primary problem before the (necessarily speculative) transpiler
      // advice, so users fix the root cause first instead of chasing
      // package-install messages.
      message = `[shakapacker-webpack] shakapacker config could not be loaded — resolve that first; the config file may be missing.
If the config is intentionally absent, install a JavaScript transpiler pair (default: @swc/core + swc-loader) or set \`javascript_transpiler: "none"\` once the config exists.`
    } else if (expectedGroup) {
      message = `[shakapacker-webpack] javascript_transpiler is "${transpilerSetting}" but ${expectedGroup.join(
        " + "
      )} is not installed in the application's node_modules.
Install: ${expectedGroup.join(" ")}
Or set \`javascript_transpiler: "none"\` in config/shakapacker.yml if you provide your own loader.`
    } else {
      message = `[shakapacker-webpack] No JavaScript transpiler is installed. Install one of:
  - @swc/core + swc-loader (recommended)
  - @babel/core + babel-loader
  - esbuild + esbuild-loader
Or set \`javascript_transpiler: "none"\` in config/shakapacker.yml if you provide your own loader.`
    }

    process.emitWarning(message, { code: NO_TRANSPILER_CODE })
  }
}

// Re-require shakapacker for the actual export. Node caches successful
// loads, so on the happy path this returns the same instance that
// `readShakapackerConfig` already touched. Failed requires are not
// cached, so on the error path this call retries and throws after the
// warnings have already fired — the ordering the tests pin.
module.exports = require("shakapacker")
