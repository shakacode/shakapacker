const {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  copyFileSync,
  symlinkSync,
  rmSync
} = require("fs")
const { tmpdir } = require("os")
const { join, resolve } = require("path")
const { spawnSync } = require("child_process")

const repoRoot = resolve(__dirname, "../../..")
const wrapperSource = join(repoRoot, "packages/shakapacker-webpack/index.js")

// Track every temp dir mkdtempSync hands out so we can rm them between
// tests. Without this, each test case leaks an app root + a virtual store
// root, which adds up across CI runs.
const dirsToClean = []

const writeModule = (root, name, source) => {
  const moduleDir = join(root, "node_modules", ...name.split("/"))
  mkdirSync(moduleDir, { recursive: true })
  writeFileSync(join(moduleDir, "index.js"), source)
}

const createPnpmLikeApp = ({ configTranspiler = "swc", transpilers = [] }) => {
  const appRoot = mkdtempSync(join(tmpdir(), "shakapacker-webpack-test-"))
  const appNodeModules = join(appRoot, "node_modules")
  const storeRoot = mkdtempSync(join(tmpdir(), "shakapacker-webpack-store-"))
  dirsToClean.push(appRoot, storeRoot)
  const virtualNodeModules = join(storeRoot, "node_modules")
  const wrapperDir = join(virtualNodeModules, "shakapacker-webpack")

  mkdirSync(wrapperDir, { recursive: true })
  copyFileSync(wrapperSource, join(wrapperDir, "index.js"))
  mkdirSync(appNodeModules, { recursive: true })
  symlinkSync(wrapperDir, join(appNodeModules, "shakapacker-webpack"), "dir")

  const shakapackerPath = join(virtualNodeModules, "shakapacker/index.js")
  writeModule(
    storeRoot,
    "shakapacker",
    `module.exports = { config: { javascript_transpiler: ${JSON.stringify(
      configTranspiler
    )} } }`
  )

  for (const transpiler of transpilers) {
    writeModule(appRoot, transpiler, "module.exports = {}")
  }

  return { appRoot, shakapackerPath }
}

const requireWrapper = (appRoot) => {
  const script = `
    const warnings = []
    process.on("warning", (warning) => {
      warnings.push({ code: warning.code, message: warning.message })
    })

    let loadError
    let exportedConfig
    try {
      exportedConfig = require("shakapacker-webpack").config
    } catch (error) {
      loadError = { code: error.code, message: error.message }
    }

    setImmediate(() => {
      console.log(JSON.stringify({ warnings, loadError, exportedConfig }))
    })
  `

  // --no-warnings stops Node from printing warnings on stderr by default,
  // but `process.on("warning", ...)` listeners still receive them. That's
  // why the structured-warning capture above works while keeping test
  // output free of the loud SHAKAPACKER_NO_TRANSPILER banner.
  const result = spawnSync(process.execPath, ["--no-warnings", "-e", script], {
    cwd: appRoot,
    encoding: "utf8"
  })

  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout)
  }

  return JSON.parse(result.stdout)
}

describe("shakapacker-webpack package wrapper", () => {
  afterEach(() => {
    for (const dir of dirsToClean.splice(0)) {
      rmSync(dir, { recursive: true, force: true })
    }
  })

  test("warns when the configured transpiler pair is not resolvable", () => {
    const { appRoot } = createPnpmLikeApp({ transpilers: [] })

    const result = requireWrapper(appRoot)

    expect(result.warnings).toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("resolves the configured transpiler pair from the application cwd", () => {
    const { appRoot } = createPnpmLikeApp({
      transpilers: ["@swc/core", "swc-loader"]
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("warns when an unrelated transpiler is installed but the configured one is not", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "swc",
      transpilers: ["@babel/core", "babel-loader"]
    })

    const result = requireWrapper(appRoot)

    const transpilerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_NO_TRANSPILER"
    )
    expect(transpilerWarning).toBeDefined()
    expect(transpilerWarning.message).toContain('javascript_transpiler is "swc"')
    expect(transpilerWarning.message).toContain("@swc/core + swc-loader")
  })

  test("respects javascript_transpiler: babel", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "babel",
      transpilers: ["@babel/core", "babel-loader"]
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("respects javascript_transpiler: esbuild", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "esbuild",
      transpilers: ["esbuild", "esbuild-loader"]
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("does not warn when javascript_transpiler is none", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "none",
      transpilers: []
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).toStrictEqual([])
  })

  test("emits the transpiler warning even when shakapacker fails to load", () => {
    const { appRoot, shakapackerPath } = createPnpmLikeApp({ transpilers: [] })
    writeFileSync(
      shakapackerPath,
      "throw Object.assign(new Error('load failed'), { code: 'LOAD_FAILED' })"
    )

    const result = requireWrapper(appRoot)

    expect(result.loadError).toStrictEqual(
      expect.objectContaining({ code: "LOAD_FAILED" })
    )
    expect(result.warnings).toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })
})
