const { mkdtempSync, rmSync, writeFileSync } = require("fs")
const { tmpdir } = require("os")
const { join } = require("path")
const {
  packageDependencyExists,
  packageMajorVersion
} = require("../../package/utils/helpers")

describe("packageMajorVersion", () => {
  test("should find that sass-loader is v16", () => {
    expect(packageMajorVersion("sass-loader")).toBe(16)
  })

  test("should find that nonexistent is v12", () => {
    expect(packageMajorVersion("nonexistent")).toBe(12)
  })
})

describe("packageDependencyExists", () => {
  let tempRoot

  afterEach(() => {
    if (tempRoot) {
      rmSync(tempRoot, { recursive: true, force: true })
      tempRoot = undefined
    }
  })

  const writePackageJson = (contents) => {
    tempRoot = mkdtempSync(join(tmpdir(), "shakapacker-package-deps-"))
    writeFileSync(join(tempRoot, "package.json"), JSON.stringify(contents))
    return tempRoot
  }

  test("detects dependencies, devDependencies, and optionalDependencies", () => {
    const root = writePackageJson({
      dependencies: { webpack: "^5.0.0" },
      devDependencies: { "babel-loader": "^10.0.0" },
      optionalDependencies: { "swc-loader": "^0.2.0" },
      peerDependencies: { esbuild: "^0.25.0" }
    })

    expect(packageDependencyExists("webpack", [root])).toBe(true)
    expect(packageDependencyExists("babel-loader", [root])).toBe(true)
    expect(packageDependencyExists("swc-loader", [root])).toBe(true)
    expect(packageDependencyExists("esbuild", [root])).toBe(false)
  })

  test("ignores missing or invalid package.json files", () => {
    const root = writePackageJson("{")

    expect(packageDependencyExists("webpack", [root])).toBe(false)
    expect(packageDependencyExists("webpack", [join(root, "missing")])).toBe(
      false
    )
  })
})
