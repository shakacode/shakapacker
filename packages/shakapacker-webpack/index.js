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

// Warn when no transpiler is resolvable. All three groups are optional peer
// deps because users pick exactly one (swc, babel, or esbuild), but installing
// none leaves the build with a cryptic loader error at first compile.
const transpilerGroups = [
  ["@swc/core", "swc-loader"],
  ["@babel/core", "babel-loader"],
  ["esbuild", "esbuild-loader"]
]

const canResolve = (mod) => {
  try {
    require.resolve(mod)
    return true
  } catch {
    return false
  }
}

const hasAnyTranspiler = transpilerGroups.some((group) =>
  group.every(canResolve)
)

// Read shakapacker config to skip the warning when the user has explicitly
// opted out via `javascript_transpiler: "none"` (e.g. they're providing
// their own loader through a custom webpack config). Wrapped in try/catch
// so that if shakapacker itself can't load (missing peer, missing
// shakapacker.yml, etc.), the warning still fires and steers the user
// toward installing a transpiler before the more cryptic core error.
let transpilerSetting
try {
  // eslint-disable-next-line global-require
  transpilerSetting = require("shakapacker")?.config?.javascript_transpiler
} catch {
  // shakapacker unavailable at require time — fall through and warn.
}

if (!hasAnyTranspiler && transpilerSetting !== "none") {
  // process.emitWarning surfaces through Node's structured warning system —
  // visible by default in stderr (including CI), suppressible with
  // --no-warnings or `process.removeAllListeners("warning")` for users who
  // know what they're doing.
  process.emitWarning(
    "[shakapacker-webpack] No JavaScript transpiler is installed. Install one of:\n" +
      "  - @swc/core + swc-loader (recommended)\n" +
      "  - @babel/core + babel-loader\n" +
      "  - esbuild + esbuild-loader\n" +
      'Or set `javascript_transpiler: "none"` in config/shakapacker.yml if you provide your own loader.',
    { code: "SHAKAPACKER_NO_TRANSPILER" }
  )
}

module.exports = require("shakapacker")
