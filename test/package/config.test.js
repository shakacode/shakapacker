const { resolve } = require("path")
const { mkdirSync, mkdtempSync, rmSync, writeFileSync } = require("fs")
const { join } = require("path")
const { tmpdir } = require("os")
const { chdirTestApp, resetEnv } = require("../helpers")

const rootPath = process.cwd()
chdirTestApp()
const testAppPath = process.cwd()

describe("Config", () => {
  let tempConfigDir
  let tempAppRoot

  beforeEach(() => jest.resetModules() && resetEnv())
  afterEach(() => {
    process.chdir(testAppPath)
    if (tempConfigDir) {
      rmSync(tempConfigDir, { recursive: true, force: true })
      tempConfigDir = undefined
    }
    if (tempAppRoot) {
      rmSync(tempAppRoot, { recursive: true, force: true })
      tempAppRoot = undefined
    }
  })
  afterAll(() => process.chdir(rootPath))

  const writeTempConfig = (contents) => {
    tempConfigDir = mkdtempSync(join(tmpdir(), "shakapacker-config-test-"))
    const configPath = join(tempConfigDir, "shakapacker.yml")
    writeFileSync(configPath, contents)
    process.env.SHAKAPACKER_CONFIG = configPath
  }

  const mockPackageHelpers = ({
    moduleExists = () => false,
    packageDependencyExists = moduleExists
  }) => {
    jest.doMock("../../package/utils/helpers", () => ({
      ...jest.requireActual("../../package/utils/helpers"),
      moduleExists,
      packageDependencyExists
    }))
  }

  const mockModuleExists = (implementation) => {
    mockPackageHelpers({ moduleExists: implementation })
  }

  const chdirTempApp = () => {
    tempAppRoot = mkdtempSync(join(tmpdir(), "shakapacker-app-root-"))
    process.chdir(tempAppRoot)
    return tempAppRoot
  }

  test("public path", () => {
    process.env.RAILS_ENV = "development"
    const config = require("../../package/config")
    expect(config.publicPath).toBe("/packs/")
  })

  test("public path with asset host", () => {
    process.env.RAILS_ENV = "development"
    process.env.SHAKAPACKER_ASSET_HOST = "http://foo.com/"
    const config = require("../../package/config")
    expect(config.publicPath).toBe("http://foo.com/packs/")
  })

  test("public path without CDN is not affected by the asset host", () => {
    process.env.RAILS_ENV = "development"
    process.env.SHAKAPACKER_ASSET_HOST = "http://foo.com/"
    const config = require("../../package/config")
    expect(config.publicPathWithoutCDN).toBe("/packs/")
  })

  test("should return additional paths as listed in app config, with resolved paths", () => {
    const config = require("../../package/config")

    expect(config.additional_paths).toStrictEqual([
      "app/assets",
      "/etc/yarn",
      "some.config.js",
      "app/elm"
    ])
  })

  test("should default manifestPath to the public dir", () => {
    const config = require("../../package/config")

    expect(config.manifestPath).toStrictEqual(
      resolve("public/packs/manifest.json")
    )
  })

  test("should allow overriding manifestPath", () => {
    process.env.SHAKAPACKER_CONFIG = "config/shakapacker_manifest_path.yml"
    const config = require("../../package/config")
    expect(config.manifestPath).toStrictEqual(
      resolve("app/javascript/manifest.json")
    )
  })

  test("should return privateOutputPath as absolute path", () => {
    const config = require("../../package/config")
    expect(config.privateOutputPath).toStrictEqual(resolve("ssr-generated"))
  })

  test("should not set privateOutputPath when not configured", () => {
    process.env.SHAKAPACKER_CONFIG = "config/shakapacker_manifest_path.yml"
    const config = require("../../package/config")
    expect(config.privateOutputPath).toBeUndefined()
  })

  test("should have integrity disabled by default", () => {
    const config = require("../../package/config")
    expect(config.integrity.enabled).toBe(false)
  })

  test("should have sha384 as default hash function", () => {
    const config = require("../../package/config")
    expect(config.integrity.hash_functions).toStrictEqual(["sha384"])
  })

  test("should have anonymous as default crossorigin", () => {
    const config = require("../../package/config")
    expect(config.integrity.cross_origin).toBe("anonymous")
  })

  test("should allow enabling integrity", () => {
    process.env.RAILS_ENV = "production"
    process.env.SHAKAPACKER_CONFIG = "config/shakapacker_integrity.yml"
    const config = require("../../package/config")

    expect(config.integrity.enabled).toBe(true)
  })

  test("should allow configuring hash functions", () => {
    process.env.RAILS_ENV = "production"
    process.env.SHAKAPACKER_CONFIG = "config/shakapacker_integrity.yml"
    const config = require("../../package/config")

    expect(config.integrity.hash_functions).toStrictEqual([
      "sha384",
      "sha256",
      "sha512"
    ])
  })

  test("should allow configuring crossorigin", () => {
    process.env.RAILS_ENV = "production"
    process.env.SHAKAPACKER_CONFIG = "config/shakapacker_integrity.yml"
    const config = require("../../package/config")

    expect(config.integrity.cross_origin).toBe("use-credentials")
  })

  describe("implicit bundled-default SWC fallback", () => {
    const minimalWebpackConfig = `
test:
  source_path: app/javascript
  source_entry_path: entrypoints
  public_root_path: public
  public_output_path: packs
  assets_bundler: webpack
`

    test("falls back to Babel when webpack uses the bundled SWC default without swc-loader", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(minimalWebpackConfig)
      mockModuleExists((packageName) => packageName === "babel-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("babel")
      expect(config.webpack_loader).toBe("babel")
      expect(warn).toHaveBeenCalledTimes(1)
      expect(warn.mock.calls[0][0]).toContain("Shakapacker defaults to SWC")
      warn.mockRestore()
    })

    test("keeps implicit SWC when swc-loader is installed", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(minimalWebpackConfig)
      mockModuleExists((packageName) => packageName === "swc-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("swc")
      expect(config.webpack_loader).toBe("swc")
      expect(warn).not.toHaveBeenCalled()
      warn.mockRestore()
    })

    test("preserves explicit SWC even when only Babel is installed", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(`${minimalWebpackConfig}  javascript_transpiler: swc\n`)
      mockModuleExists((packageName) => packageName === "babel-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("swc")
      expect(config.webpack_loader).toBe("swc")
      expect(warn).not.toHaveBeenCalled()
      warn.mockRestore()
    })

    test("preserves explicit webpack_loader even when bundled defaults include SWC", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(`${minimalWebpackConfig}  webpack_loader: babel\n`)
      mockModuleExists((packageName) => packageName === "babel-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("babel")
      expect(config.webpack_loader).toBe("babel")
      expect(warn).toHaveBeenCalledTimes(1)
      expect(warn.mock.calls[0][0]).toContain("webpack_loader")
      warn.mockRestore()
    })

    test("preserves explicit production fallback transpiler when Rails env is missing", () => {
      process.env.RAILS_ENV = "staging"
      writeTempConfig(
        minimalWebpackConfig
          .replace("test:", "production:")
          .concat('  javascript_transpiler: "none"\n')
      )
      mockModuleExists((packageName) => packageName === "babel-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      try {
        const config = require("../../package/config")

        expect(config.javascript_transpiler).toBe("none")
        expect(config.webpack_loader).toBe("none")
        expect(
          warn.mock.calls.some(([message]) =>
            message.includes("Environment 'staging' not found")
          )
        ).toBe(true)
        expect(
          warn.mock.calls.some(([message]) =>
            message.includes("Using 'development' configuration")
          )
        ).toBe(false)
        expect(
          warn.mock.calls.some(([message]) =>
            message.includes("Shakapacker defaults to SWC")
          )
        ).toBe(false)
      } finally {
        warn.mockRestore()
      }
    })

    test("uses production fallback instead of normalized development when requested Rails env is missing", () => {
      process.env.RAILS_ENV = "staging"
      writeTempConfig(
        minimalWebpackConfig
          .replace("test:", "production:")
          .concat('  javascript_transpiler: "none"\n')
          .concat("development:\n")
          .concat("  source_path: app/javascript\n")
          .concat("  source_entry_path: packs\n")
          .concat("  public_root_path: public\n")
          .concat("  public_output_path: packs\n")
          .concat("  assets_bundler: webpack\n")
      )
      mockModuleExists((packageName) => packageName === "babel-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      try {
        const config = require("../../package/config")

        expect(config.javascript_transpiler).toBe("none")
        expect(config.webpack_loader).toBe("none")
        expect(
          warn.mock.calls.some(([message]) =>
            message.includes("Environment 'staging' not found")
          )
        ).toBe(true)
        expect(
          warn.mock.calls.some(([message]) =>
            message.includes("Shakapacker defaults to SWC")
          )
        ).toBe(false)
      } finally {
        warn.mockRestore()
      }
    })

    test("treats blank webpack_loader as implicit and falls back to Babel", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(`${minimalWebpackConfig}  webpack_loader:\n`)
      mockModuleExists((packageName) => packageName === "babel-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("babel")
      expect(config.webpack_loader).toBe("babel")
      expect(warn).toHaveBeenCalledTimes(1)
      expect(warn.mock.calls[0][0]).toContain("Shakapacker defaults to SWC")
      warn.mockRestore()
    })

    test("treats empty javascript_transpiler as implicit and falls back to Babel", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(`${minimalWebpackConfig}  javascript_transpiler: ""\n`)
      mockModuleExists((packageName) => packageName === "babel-loader")
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("babel")
      expect(config.webpack_loader).toBe("babel")
      expect(warn).toHaveBeenCalledTimes(1)
      expect(warn.mock.calls[0][0]).toContain("Shakapacker defaults to SWC")
      warn.mockRestore()
    })

    test("continues past bare node_modules markers to find package.json declarations", () => {
      const appRoot = chdirTempApp()
      process.env.RAILS_ENV = "test"
      writeTempConfig(`
test:
  source_path: workspace/nested/app/javascript
  source_entry_path: entrypoints
  public_root_path: public
  public_output_path: packs
  assets_bundler: webpack
`)
      mkdirSync(join(appRoot, "workspace/nested/node_modules"), {
        recursive: true
      })
      writeFileSync(
        join(appRoot, "workspace/package.json"),
        JSON.stringify({ devDependencies: { "babel-loader": "^10.0.0" } })
      )
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("babel")
      expect(config.webpack_loader).toBe("babel")
      expect(warn.mock.calls[0][0]).toContain("Shakapacker defaults to SWC")
      warn.mockRestore()
    })

    test("uses package declarations for fallback instead of stale installed modules", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(minimalWebpackConfig)
      mockPackageHelpers({
        moduleExists: (packageName) => packageName === "swc-loader",
        packageDependencyExists: (packageName) => packageName === "babel-loader"
      })
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("babel")
      expect(config.webpack_loader).toBe("babel")
      expect(warn.mock.calls[0][0]).toContain("Shakapacker defaults to SWC")
      warn.mockRestore()
    })

    test("memoizes package root paths while checking fallback dependencies", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(minimalWebpackConfig)
      const seenPackageRootPaths = []
      mockPackageHelpers({
        packageDependencyExists: (packageName, packageRootPaths) => {
          seenPackageRootPaths.push(packageRootPaths)
          return packageName === "babel-loader"
        }
      })
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      require("../../package/config")

      expect(seenPackageRootPaths).toHaveLength(2)
      expect(seenPackageRootPaths[0]).toBe(seenPackageRootPaths[1])
      warn.mockRestore()
    })

    test("preserves rspack SWC behavior without checking swc-loader", () => {
      process.env.RAILS_ENV = "test"
      writeTempConfig(minimalWebpackConfig.replace("webpack", "rspack"))
      mockModuleExists(() => false)
      const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

      const config = require("../../package/config")

      expect(config.javascript_transpiler).toBe("swc")
      expect(config.webpack_loader).toBe("swc")
      expect(warn).not.toHaveBeenCalled()
      warn.mockRestore()
    })
  })
})
