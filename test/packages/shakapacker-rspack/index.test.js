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
const wrapperSource = join(repoRoot, "packages/shakapacker-rspack/index.js")

const dirsToClean = []

const writeModule = (root, name, source) => {
  const moduleDir = join(root, "node_modules", ...name.split("/"))
  mkdirSync(moduleDir, { recursive: true })
  writeFileSync(join(moduleDir, "index.js"), source)
}

const createPnpmLikeApp = (options = {}) => {
  const configBundler = Object.prototype.hasOwnProperty.call(
    options,
    "configBundler"
  )
    ? options.configBundler
    : "rspack"
  const {
    // When false, omit the shakapacker/package/config module so the wrapper's
    // first require throws and the fallback to `require("shakapacker")?.config`
    // is exercised. The default writes both entries, matching real installs.
    writePackageConfig = true,
    shakapackerRootSource = `module.exports = { config: require("./package/config") }`,
    shakapackerRspackSource = `module.exports = { config: require("../package/config"), rspackEntrypoint: true }`
  } = options

  const appRoot = mkdtempSync(join(tmpdir(), "shakapacker-rspack-test-"))
  const appNodeModules = join(appRoot, "node_modules")
  const storeRoot = mkdtempSync(join(tmpdir(), "shakapacker-rspack-store-"))
  dirsToClean.push(appRoot, storeRoot)
  const virtualNodeModules = join(storeRoot, "node_modules")
  const wrapperDir = join(virtualNodeModules, "shakapacker-rspack")

  mkdirSync(wrapperDir, { recursive: true })
  copyFileSync(wrapperSource, join(wrapperDir, "index.js"))
  mkdirSync(appNodeModules, { recursive: true })
  symlinkSync(wrapperDir, join(appNodeModules, "shakapacker-rspack"), "dir")

  const configEntries = []
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
  writeModule(storeRoot, "shakapacker", shakapackerRootSource)
  writeModule(storeRoot, "shakapacker/rspack", shakapackerRspackSource)

  return { appRoot }
}

const requireWrapper = (appRoot) => {
  const script = `
    const warnings = []
    process.on("warning", (warning) => {
      warnings.push({ code: warning.code, message: warning.message })
    })

    let loadError
    let exportedConfig
    let rspackEntrypoint
    try {
      const wrapper = require("shakapacker-rspack")
      exportedConfig = wrapper.config
      rspackEntrypoint = wrapper.rspackEntrypoint
    } catch (error) {
      loadError = { code: error.code, message: error.message }
    }

    setImmediate(() => {
      console.log(JSON.stringify({
        warnings,
        loadError,
        exportedConfig,
        rspackEntrypoint
      }))
    })
  `

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

describe("shakapacker-rspack package wrapper", () => {
  afterEach(() => {
    for (const dir of dirsToClean.splice(0)) {
      rmSync(dir, { recursive: true, force: true })
    }
  })

  test("does not warn when assets_bundler is set to rspack", () => {
    const { appRoot } = createPnpmLikeApp({ configBundler: "rspack" })

    const result = requireWrapper(appRoot)

    expect(result.rspackEntrypoint).toBe(true)
    expect(result.warnings).not.toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: "SHAKAPACKER_BUNDLER_MISMATCH" })
      ])
    )
  })

  test("warns when assets_bundler is set to webpack", () => {
    const { appRoot } = createPnpmLikeApp({ configBundler: "webpack" })

    const result = requireWrapper(appRoot)

    const bundlerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_BUNDLER_MISMATCH"
    )
    expect(bundlerWarning).toBeDefined()
    expect(bundlerWarning.message).toContain('assets_bundler is "webpack"')
    expect(bundlerWarning.message).toContain("shakapacker-webpack")
    expect(bundlerWarning.message).toContain("assets_bundler: rspack")
  })

  test("warns when assets_bundler is unset", () => {
    const { appRoot } = createPnpmLikeApp({ configBundler: undefined })

    const result = requireWrapper(appRoot)

    const bundlerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_BUNDLER_MISMATCH"
    )
    expect(bundlerWarning).toBeDefined()
    expect(bundlerWarning.message).toContain(
      'assets_bundler is unset, which defaults to "webpack"'
    )
    expect(bundlerWarning.message).toContain("assets_bundler: rspack")
  })

  test("warns before the rspack entrypoint throws", () => {
    const { appRoot } = createPnpmLikeApp({
      configBundler: "webpack",
      shakapackerRootSource:
        "throw Object.assign(new Error('root load failed'), { code: 'ROOT_LOAD_FAILED' })",
      shakapackerRspackSource:
        "throw Object.assign(new Error('rspack load failed'), { code: 'RSPACK_LOAD_FAILED' })"
    })

    const result = requireWrapper(appRoot)

    expect(result.loadError).toStrictEqual(
      expect.objectContaining({ code: "RSPACK_LOAD_FAILED" })
    )
    const bundlerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_BUNDLER_MISMATCH"
    )
    expect(bundlerWarning).toBeDefined()
    expect(bundlerWarning.message).toContain('assets_bundler is "webpack"')
  })

  // The wrapper reads `shakapacker/package/config` first because that
  // subpath loads the YAML config without dragging in webpack/rspack
  // rules. Older core versions (predating the explicit subpath export)
  // and any future reorganization that moves `package/` need to keep
  // working via the fallback `require("shakapacker").config`. This test
  // pins that fallback so a silent regression — wrapper stops emitting
  // the bundler-mismatch warning — would fail CI.
  test("falls back to shakapacker.config when the package/config subpath is unresolvable", () => {
    const { appRoot } = createPnpmLikeApp({
      configBundler: "webpack",
      writePackageConfig: false,
      shakapackerRootSource:
        'module.exports = { config: { assets_bundler: "webpack" } }',
      shakapackerRspackSource: "module.exports = { rspackEntrypoint: true }"
    })

    const result = requireWrapper(appRoot)

    expect(result.rspackEntrypoint).toBe(true)
    const bundlerWarning = result.warnings.find(
      (warning) => warning.code === "SHAKAPACKER_BUNDLER_MISMATCH"
    )
    expect(bundlerWarning).toBeDefined()
    expect(bundlerWarning.message).toContain('assets_bundler is "webpack"')
  })
})
