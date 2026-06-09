const { resolve } = require("path")

const mapping = {
  "css-loader": "this path was mocked",
  "sass-loader/package.json": "../../__mocks__/sass-loader/package.json",
  "nonexistent/package.json": "../../__mocks__/nonexistent/package.json"
}

const repoRoot = resolve(__dirname, "..")
// Keep this map explicit to avoid accidentally rewriting third-party imports.
// If a new local bundler TS module is required via its compiled .js path in tests,
// add the corresponding mapping here.
const bundlerModuleAliasMap = {
  [resolve(repoRoot, "package/plugins/webpack.js")]: resolve(
    repoRoot,
    "package/plugins/webpack.ts"
  ),
  [resolve(repoRoot, "package/plugins/rspack.js")]: resolve(
    repoRoot,
    "package/plugins/rspack.ts"
  ),
  [resolve(repoRoot, "package/rules/webpack.js")]: resolve(
    repoRoot,
    "package/rules/webpack.ts"
  ),
  [resolve(repoRoot, "package/rules/rspack.js")]: resolve(
    repoRoot,
    "package/rules/rspack.ts"
  ),
  [resolve(repoRoot, "package/optimization/webpack.js")]: resolve(
    repoRoot,
    "package/optimization/webpack.ts"
  ),
  [resolve(repoRoot, "package/optimization/rspack.js")]: resolve(
    repoRoot,
    "package/optimization/rspack.ts"
  )
}

function resolver(module, options) {
  if (mapping[module]) {
    return mapping[module]
  }

  // Remap only this repository's known bundler JS targets to TS sources.
  if (options.basedir) {
    const requestedPath = resolve(options.basedir, module)
    if (bundlerModuleAliasMap[requestedPath]) {
      return bundlerModuleAliasMap[requestedPath]
    }
  }

  return options.defaultResolver(module, options)
}

module.exports = resolver
