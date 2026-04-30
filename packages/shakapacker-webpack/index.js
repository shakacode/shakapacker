// This thin re-export forwards to the core `shakapacker` package. The value
// is in this package's tighter peer-dependency declarations, not the runtime
// surface; see packages/shakapacker-webpack/package.json. The compiled core
// is built by the upstream `shakapacker` package's `prepublishOnly`; for local
// monorepo development run `yarn build` in the repository root first.

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

if (!hasAnyTranspiler) {
  console.warn(
    "[shakapacker-webpack] No JavaScript transpiler is installed. Install one of:\n" +
      "  - @swc/core + swc-loader (recommended)\n" +
      "  - @babel/core + babel-loader\n" +
      "  - esbuild + esbuild-loader"
  )
}

module.exports = require("shakapacker")
