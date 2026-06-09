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

const createPnpmLikeApp = (options = {}) => {
  const { configTranspiler = "swc", transpilers = [] } = options
  const configBundler = Object.prototype.hasOwnProperty.call(
    options,
    "configBundler"
  )
    ? options.configBundler
    : "webpack"
  // When false, omit the shakapacker/package/config module so the wrapper
  // exercises the fallback to `require("shakapacker").config`. Default
  // matches real installs.
  const { writePackageConfig = true } = options

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
  const configEntries = [
    `javascript_transpiler: ${JSON.stringify(configTranspiler)}`
  ]
  if (configBundler !== undefined) {
    configEntries.push(`assets_bundler: ${JSON.stringify(configBundler)}`)
  }

  if (writePackageConfig) {
    writeModule(
      storeRoot,
      "shakapacker/package/config",
      `module.exports = { ${configEntries.join(", ")} }`
    )
  }
  writeModule(
    storeRoot,
    "shakapacker",
    `module.exports = { config: { ${configEntries.join(", ")} } }`
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
  // 5 s timeout keeps a stuck child from hanging the entire suite in CI;
  // every passing run completes in well under a second.
  const result = spawnSync(process.execPath, ["--no-warnings", "-e", script], {
    cwd: appRoot,
    encoding: "utf8",
    timeout: 5000
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
    expect(transpilerWarning.message).toContain(
      'javascript_transpiler is "swc"'
    )
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

  test("emits a load-failure-first transpiler warning when shakapacker config cannot be read", () => {
    const { appRoot, shakapackerPath } = createPnpmLikeApp({
      transpilers: [],
      writePackageConfig: false
    })
    writeFileSync(
      shakapackerPath,
      "throw Object.assign(new Error('load failed'), { code: 'LOAD_FAILED' })"
    )

    const result = requireWrapper(appRoot)

    expect(result.loadError).toStrictEqual(
      expect.objectContaining({ code: "LOAD_FAILED" })
    )
    const transpilerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_NO_TRANSPILER"
    )
    expect(transpilerWarning).toBeDefined()
    // Load failure is surfaced first so users fix the root cause before
    // chasing transpiler installs.
    expect(transpilerWarning.message).toContain(
      "shakapacker config could not be loaded"
    )
    // Recommendation lists the supported transpiler pairs alongside the
    // matching `javascript_transpiler:` value the user must set, so a
    // user who installs SWC per the message and then defaults
    // `javascript_transpiler:` to the code-fallback (babel) doesn't trip
    // a follow-on babel-loader warning.
    expect(transpilerWarning.message).toContain("@swc/core + swc-loader")
    expect(transpilerWarning.message).toContain('javascript_transpiler: "swc"')
    expect(transpilerWarning.message).toContain("@babel/core + babel-loader")
  })

  test("does not warn when shakapacker config cannot be read but a valid transpiler pair is installed", () => {
    const { appRoot, shakapackerPath } = createPnpmLikeApp({
      transpilers: ["@swc/core", "swc-loader"],
      writePackageConfig: false
    })
    writeFileSync(
      shakapackerPath,
      "throw Object.assign(new Error('load failed'), { code: 'LOAD_FAILED' })"
    )

    const result = requireWrapper(appRoot)

    expect(result.loadError).toStrictEqual(
      expect.objectContaining({ code: "LOAD_FAILED" })
    )
    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("warns when only one module of the configured transpiler pair is installed", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "swc",
      transpilers: ["@swc/core"]
    })

    const result = requireWrapper(appRoot)

    const transpilerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_NO_TRANSPILER"
    )
    expect(transpilerWarning).toBeDefined()
    expect(transpilerWarning.message).toContain("@swc/core + swc-loader")
  })

  test("emits generic transpiler warning for unrecognized javascript_transpiler value", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "custom",
      transpilers: []
    })

    const result = requireWrapper(appRoot)

    const transpilerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_NO_TRANSPILER"
    )
    expect(transpilerWarning).toBeDefined()
    expect(transpilerWarning.message).toContain(
      "No JavaScript transpiler is installed"
    )
  })

  test("does not emit transpiler warning when an unrecognized transpiler value sees any pair installed", () => {
    const { appRoot } = createPnpmLikeApp({
      configTranspiler: "custom",
      transpilers: ["@babel/core", "babel-loader"]
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("warns when assets_bundler is set to a non-webpack value", () => {
    const { appRoot } = createPnpmLikeApp({
      configBundler: "rspack",
      transpilers: ["@swc/core", "swc-loader"]
    })

    const result = requireWrapper(appRoot)

    const bundlerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_BUNDLER_MISMATCH"
    )
    expect(bundlerWarning).toBeDefined()
    expect(bundlerWarning.message).toContain('assets_bundler is "rspack"')
    expect(bundlerWarning.message).toContain("shakapacker-rspack")
  })

  test("does not double-warn with NO_TRANSPILER when bundler is mismatched", () => {
    // Rspack ships SWC built in, so a real rspack user with no
    // webpack-stack transpilers would otherwise hit both
    // SHAKAPACKER_BUNDLER_MISMATCH and SHAKAPACKER_NO_TRANSPILER. Only the
    // bundler mismatch is actionable; the transpiler warning would be
    // misleading noise.
    const { appRoot } = createPnpmLikeApp({
      configBundler: "rspack",
      configTranspiler: "swc",
      transpilers: []
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_BUNDLER_MISMATCH" })
      ])
    )
    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_NO_TRANSPILER" })
      ])
    )
  })

  test("does not warn about assets_bundler when set to webpack", () => {
    const { appRoot } = createPnpmLikeApp({
      configBundler: "webpack",
      transpilers: ["@swc/core", "swc-loader"]
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_BUNDLER_MISMATCH" })
      ])
    )
  })

  test("does not warn about assets_bundler when unset", () => {
    const { appRoot } = createPnpmLikeApp({
      configBundler: undefined,
      transpilers: ["@swc/core", "swc-loader"]
    })

    const result = requireWrapper(appRoot)

    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_BUNDLER_MISMATCH" })
      ])
    )
  })

  // The wrapper reads `shakapacker/package/config` first because that
  // subpath loads the YAML config without dragging in webpack-specific
  // rule modules. Older core versions (predating the explicit subpath
  // export) and any future reorganization that moves `package/` need to
  // keep working via the fallback `require("shakapacker").config`. This
  // test pins that fallback so a silent regression — wrapper stops
  // emitting bundler-mismatch warnings — would fail CI. Mirrors the same
  // assertion in test/packages/shakapacker-rspack/index.test.js.
  test("falls back to shakapacker.config when the package/config subpath is unresolvable", () => {
    const { appRoot } = createPnpmLikeApp({
      configBundler: "rspack",
      transpilers: ["@swc/core", "swc-loader"],
      writePackageConfig: false
    })

    const result = requireWrapper(appRoot)

    const bundlerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_BUNDLER_MISMATCH"
    )
    expect(bundlerWarning).toBeDefined()
    expect(bundlerWarning.message).toContain('assets_bundler is "rspack"')
  })
})
