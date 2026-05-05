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
// fires and steers the user toward installing a transpiler before the
// more cryptic core error.
let transpilerSetting
try {
  // eslint-disable-next-line global-require
  transpilerSetting = require("shakapacker")?.config?.javascript_transpiler
} catch {
  // shakapacker unavailable at require time — fall through and warn.
}

if (transpilerSetting !== "none") {
  // When the config names a known transpiler, only that pair counts —
  // unrelated transpilers being installed shouldn't mask a missing peer.
  // When the setting is missing or unrecognized (config load failed,
  // custom value), fall back to "any pair resolves" so the wrapper still
  // does something useful instead of silently warning.
  const expectedGroup = transpilerGroups[transpilerSetting]
  const hasExpectedTranspiler = expectedGroup
    ? expectedGroup.every(canResolve)
    : Object.values(transpilerGroups).some((group) => group.every(canResolve))

  if (!hasExpectedTranspiler) {
    // process.emitWarning surfaces through Node's structured warning system —
    // visible by default in stderr (including CI), suppressible with
    // --no-warnings or `process.removeAllListeners("warning")` for users who
    // know what they're doing.
    const message = expectedGroup
      ? `[shakapacker-webpack] javascript_transpiler is "${transpilerSetting}" but ${expectedGroup.join(
          " + "
        )} is not installed in the application's node_modules.\n` +
        `Install: ${expectedGroup.join(" ")}\n` +
        'Or set `javascript_transpiler: "none"` in config/shakapacker.yml if you provide your own loader.'
      : "[shakapacker-webpack] No JavaScript transpiler is installed. Install one of:\n" +
        "  - @swc/core + swc-loader (recommended)\n" +
        "  - @babel/core + babel-loader\n" +
        "  - esbuild + esbuild-loader\n" +
        'Or set `javascript_transpiler: "none"` in config/shakapacker.yml if you provide your own loader.'

    process.emitWarning(message, { code: "SHAKAPACKER_NO_TRANSPILER" })
  }
}

module.exports = require("shakapacker")
