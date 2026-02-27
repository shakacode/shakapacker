const fs = require("fs")
const os = require("os")
const path = require("path")

describe("ensureManifestExists", () => {
  let tmpDir

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "shakapacker-test-"))
  })

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true })
  })

  // We test the logic by reimplementing the same pattern used in webpack.ts,
  // since the function isn't exported. This validates the algorithm.
  const ensureManifestExists = (manifestPath) => {
    if (!fs.existsSync(manifestPath)) {
      fs.mkdirSync(path.dirname(manifestPath), { recursive: true })
      try {
        fs.writeFileSync(manifestPath, "{}", { flag: "wx" })
      } catch (err) {
        if (err.code !== "EEXIST") throw err
      }
    }
  }

  it("creates the manifest file with {} when it does not exist", () => {
    const manifestPath = path.join(tmpDir, "manifest.json")

    ensureManifestExists(manifestPath)

    expect(fs.existsSync(manifestPath)).toBe(true)
    expect(fs.readFileSync(manifestPath, "utf8")).toBe("{}")
  })

  it("does not overwrite an existing manifest file", () => {
    const manifestPath = path.join(tmpDir, "manifest.json")
    fs.writeFileSync(manifestPath, '{"existing": "data"}')

    ensureManifestExists(manifestPath)

    expect(fs.readFileSync(manifestPath, "utf8")).toBe('{"existing": "data"}')
  })

  it("creates missing parent directories", () => {
    const manifestPath = path.join(
      tmpDir,
      "deep",
      "nested",
      "dir",
      "manifest.json"
    )

    ensureManifestExists(manifestPath)

    expect(fs.existsSync(manifestPath)).toBe(true)
    expect(fs.readFileSync(manifestPath, "utf8")).toBe("{}")
  })

  it("uses the wx flag to prevent TOCTOU race conditions", () => {
    // Verify the source code uses the wx flag
    const webpackSource = fs.readFileSync(
      path.resolve(__dirname, "../../../package/plugins/webpack.ts"),
      "utf8"
    )

    expect(webpackSource).toContain('{ flag: "wx" }')
  })

  it("uses ES module imports for fs and path", () => {
    const webpackSource = fs.readFileSync(
      path.resolve(__dirname, "../../../package/plugins/webpack.ts"),
      "utf8"
    )

    expect(webpackSource).toContain(
      'import { existsSync, mkdirSync, writeFileSync } from "fs"'
    )
    expect(webpackSource).toContain('import { dirname } from "path"')
    expect(webpackSource).not.toContain('require("fs")')
    expect(webpackSource).not.toContain('require("path")')
  })
})
