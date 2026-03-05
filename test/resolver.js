const { resolve } = require("path")

const mapping = {
  "css-loader": "this path was mocked",
  "sass-loader/package.json": "../../__mocks__/sass-loader/package.json",
  "nonexistent/package.json": "../../__mocks__/nonexistent/package.json"
}

const repoRoot = resolve(__dirname, "..")
const rspackModuleAliasMap = {
  [resolve(repoRoot, "package/plugins/rspack.js")]: resolve(
    repoRoot,
    "package/plugins/rspack.ts"
  ),
  [resolve(repoRoot, "package/rules/rspack.js")]: resolve(
    repoRoot,
    "package/rules/rspack.ts"
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

  // Remap only this repository's known rspack JS targets to TS sources.
  if (options.basedir) {
    const requestedPath = resolve(options.basedir, module)
    if (rspackModuleAliasMap[requestedPath]) {
      return rspackModuleAliasMap[requestedPath]
    }
  }

  return options.defaultResolver(module, options)
}

module.exports = resolver
