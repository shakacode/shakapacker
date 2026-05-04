const {
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  copyFileSync,
  symlinkSync
} = require("fs")
const { tmpdir } = require("os")
const { join, resolve } = require("path")
const { spawnSync } = require("child_process")

const repoRoot = resolve(__dirname, "../../..")
const wrapperSource = join(repoRoot, "packages/shakapacker-webpack/index.js")

const writeModule = (root, name, source) => {
  const moduleDir = join(root, "node_modules", ...name.split("/"))
  mkdirSync(moduleDir, { recursive: true })
  writeFileSync(join(moduleDir, "index.js"), source)
}

const createPnpmLikeApp = ({ configTranspiler = "swc", transpilers = [] }) => {
  const appRoot = mkdtempSync(join(tmpdir(), "shakapacker-webpack-test-"))
  const appNodeModules = join(appRoot, "node_modules")
  const storeRoot = mkdtempSync(join(tmpdir(), "shakapacker-webpack-store-"))
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
  test("warns when no transpiler pair is resolvable", () => {
    const { appRoot } = createPnpmLikeApp({ transpilers: [] })

    const result = requireWrapper(appRoot)

    expect(result.warnings).toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("resolves transpiler pairs from the application cwd", () => {
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

  test("does not warn when javascript_transpiler is none", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "none",
      transpilers: []
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).toStrictEqual([])
  })

  test("emits the transpiler warning before rethrowing when shakapacker cannot load", () => {
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
