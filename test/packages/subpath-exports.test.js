const { resolve } = require("path")

// Catch the regression where `shakapacker/package/config` resolves only
// via the wildcard subpath export `"./package/*": "./package/*"` — that
// path does not append `.js`, so production installs hit MODULE_NOT_FOUND
// while the wrapper tests (which build virtual modules without an
// `exports` field) still pass. Requiring the real installed package
// catches it.

const repoRoot = resolve(__dirname, "../..")

describe("shakapacker subpath exports", () => {
  test("require('shakapacker/package/config') resolves against the real package", () => {
    // Resolve from the repo root so Node walks up node_modules from a
    // location that has the package installed (the real shakapacker is
    // the workspace itself).
    const resolved = require.resolve("shakapacker/package/config", {
      paths: [repoRoot]
    })
    expect(resolved).toMatch(/package[/\\]config\.js$/)

    // eslint-disable-next-line import/no-dynamic-require
    const config = require(resolved)
    expect(config).toBeDefined()
    expect(typeof config).toBe("object")
  })
})
