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

// Read shakapacker config so the warning can be scoped to the configured
// transpiler. Wrapped in try/catch so that if shakapacker itself can't
// load (missing peer, missing shakapacker.yml, etc.), the warning still
// fires before the core error and carries a hint to fix that load failure
// before changing transpiler packages.
let bundlerSetting
let transpilerSetting
let shakapackerLoadFailed = false
try {
  // eslint-disable-next-line global-require
  const shakapackerExports = require("shakapacker")
  bundlerSetting = shakapackerExports?.config?.assets_bundler
  transpilerSetting = shakapackerExports?.config?.javascript_transpiler
} catch {
  shakapackerLoadFailed = true
}

// Detect the misconfiguration where shakapacker-webpack is installed but
// the app is configured to use rspack. Re-exporting the root shakapacker
// follows config.assets_bundler into rspack rules/plugins, which then
// requires rspack-only packages this wrapper does not declare as peers.
// Surfacing a structured warning is cheaper than the cryptic loader
// errors that follow. Only fires when assets_bundler is explicitly set to
// something other than "webpack" (the default), so apps that omit it are
// silent.
if (bundlerSetting && bundlerSetting !== "webpack") {
  process.emitWarning(
    `[shakapacker-webpack] config.assets_bundler is "${bundlerSetting}" but this package only supports webpack.\n` +
      `Install shakapacker-rspack and require it instead, or set \`assets_bundler: webpack\` in config/shakapacker.yml.`,
    { code: "SHAKAPACKER_BUNDLER_MISMATCH" }
  )
}

if (transpilerSetting !== "none") {
  // When the config names a known transpiler, only that pair counts —
  // unrelated transpilers being installed shouldn't mask a missing peer.
  // When the setting is missing (config load failed) we default to
  // "swc" — the recommended transpiler — so the warning is actionable
  // ("install @swc/core + swc-loader") instead of the generic
  // pick-from-three. Unrecognized values (e.g. "custom") still fall back
  // to "any pair resolves" since we genuinely don't know what the user
  // configured.
  const effectiveTranspiler = transpilerSetting ?? "swc"
  const expectedGroup = transpilerGroups[effectiveTranspiler]
  const hasExpectedTranspiler = expectedGroup
    ? expectedGroup.every(canResolve)
    : Object.values(transpilerGroups).some((group) => group.every(canResolve))

  if (!hasExpectedTranspiler) {
    // process.emitWarning surfaces through Node's structured warning system —
    // visible by default in stderr (including CI), suppressible with
    // --no-warnings or `process.removeAllListeners("warning")` for users who
    // know what they're doing.
    const shakapackerLoadHint = shakapackerLoadFailed
      ? "\nIf shakapacker failed to load, resolve that error first; the config file may be missing."
      : ""
    const message = expectedGroup
      ? `[shakapacker-webpack] javascript_transpiler is "${effectiveTranspiler}" but ${expectedGroup.join(
          " + "
        )} is not installed in the application's node_modules.
Install: ${expectedGroup.join(" ")}
Or set \`javascript_transpiler: "none"\` in config/shakapacker.yml if you provide your own loader.${shakapackerLoadHint}`
      : `[shakapacker-webpack] No JavaScript transpiler is installed. Install one of:
  - @swc/core + swc-loader (recommended)
  - @babel/core + babel-loader
  - esbuild + esbuild-loader
Or set \`javascript_transpiler: "none"\` in config/shakapacker.yml if you provide your own loader.${shakapackerLoadHint}`

    process.emitWarning(message, { code: "SHAKAPACKER_NO_TRANSPILER" })
  }
}

// Re-require shakapacker for the actual export. Node caches successful
// loads, so on the happy path this returns the same instance read above
// at zero cost. On the error path the cached module is evicted and this
// call throws too — after the warning has already fired, which is the
// behaviour the tests pin. Don't hoist this require into a shared
// variable: the warning-before-error ordering depends on the read above
// being inside its own try/catch.
module.exports = require("shakapacker")
