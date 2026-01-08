/* eslint-disable func-names, jest/prefer-strict-equal */

// Mock helpers before requiring the plugins module
jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  return {
    ...original,
    moduleExists: jest.fn(() => true)
  }
})

// Mock requireOrError to prevent actual module loading
jest.mock("../../../package/utils/requireOrError", () => ({
  requireOrError: (moduleName) => {
    if (moduleName === "rspack-manifest-plugin") {
      return {
        RspackManifestPlugin: jest.fn(function (options) {
          this.options = options
          this.name = "RspackManifestPlugin"
        })
      }
    }
    if (moduleName === "@rspack/core") {
      return {
        EnvironmentPlugin: jest.fn(function (env) {
          this.env = env
          this.name = "EnvironmentPlugin"
        }),
        CssExtractRspackPlugin: jest.fn(function (options) {
          this.options = options
          this.name = "CssExtractRspackPlugin"
        }),
        SubresourceIntegrityPlugin: jest.fn(function (options) {
          this.options = options
          this.name = "SubresourceIntegrityPlugin"
        })
      }
    }
    throw new Error(`Module ${moduleName} not found`)
  }
}))

describe("rspack/plugins", () => {
  let getPlugins
  let moduleExists

  beforeEach(() => {
    jest.resetModules()
    moduleExists = require("../../../package/utils/helpers").moduleExists
    const pluginsModule = require("../../../package/plugins/rspack")
    getPlugins = pluginsModule.getPlugins
  })

  afterEach(() => {
    jest.clearAllMocks()
  })

  describe("getPlugins", () => {
    test("returns an array", () => {
      const plugins = getPlugins()
      expect(Array.isArray(plugins)).toBe(true)
    })

    test("includes EnvironmentPlugin with filtered env", () => {
      const plugins = getPlugins()
      const envPlugin = plugins.find((p) => p.name === "EnvironmentPlugin")
      expect(envPlugin).toBeDefined()
      // EnvironmentPlugin receives getFilteredEnv() - a security-filtered version of process.env
      // that only includes allowlisted environment variables
      expect(envPlugin.env).toBeDefined()
      expect(typeof envPlugin.env).toBe("object")
    })

    test("includes RspackManifestPlugin", () => {
      const plugins = getPlugins()
      const manifestPlugin = plugins.find(
        (p) => p.name === "RspackManifestPlugin"
      )
      expect(manifestPlugin).toBeDefined()
      expect(manifestPlugin.options).toBeDefined()
      expect(manifestPlugin.options.writeToFileEmit).toBe(true)
    })

    test("rspackManifestPlugin has generate function", () => {
      const plugins = getPlugins()
      const manifestPlugin = plugins.find(
        (p) => p.name === "RspackManifestPlugin"
      )
      expect(manifestPlugin.options.generate).toBeInstanceOf(Function)
    })

    test("rspackManifestPlugin generate creates proper manifest structure", () => {
      const plugins = getPlugins()
      const manifestPlugin = plugins.find(
        (p) => p.name === "RspackManifestPlugin"
      )

      const files = [
        { name: "app.js", path: "/packs/app-123.js" },
        { name: "app.css", path: "/packs/app-456.css" }
      ]

      const entrypoints = {
        app: ["app-123.js", "app-456.css"]
      }

      const manifest = manifestPlugin.options.generate(null, files, entrypoints)

      expect(manifest["app.js"]).toBe("/packs/app-123.js")
      expect(manifest["app.css"]).toBe("/packs/app-456.css")
      expect(manifest).toHaveProperty("entrypoints")
      expect(manifest.entrypoints).toHaveProperty("app")
      expect(manifest.entrypoints.app).toHaveProperty("assets")
    })

    test("rspackManifestPlugin filters hot-update files", () => {
      const plugins = getPlugins()
      const manifestPlugin = plugins.find(
        (p) => p.name === "RspackManifestPlugin"
      )

      const files = []
      const entrypoints = {
        app: [
          "app-123.js",
          "app.hot-update.js",
          "app-456.css",
          "app.hot-update.css"
        ]
      }

      const manifest = manifestPlugin.options.generate(null, files, entrypoints)

      expect(manifest.entrypoints.app.assets.js).toEqual(["/packs/app-123.js"])
      expect(manifest.entrypoints.app.assets.css).toEqual([
        "/packs/app-456.css"
      ])
    })

    test("includes CssExtractRspackPlugin when css-loader exists", () => {
      moduleExists.mockReturnValue(true)

      const pluginsModule = require("../../../package/plugins/rspack")
      const plugins = pluginsModule.getPlugins()

      const cssPlugin = plugins.find((p) => p.name === "CssExtractRspackPlugin")
      expect(cssPlugin).toBeDefined()
      expect(cssPlugin.options.filename).toMatch(/^css\//)
    })

    test("conditionally includes CssExtractRspackPlugin based on css-loader", () => {
      // CssExtractRspackPlugin should be present since moduleExists is mocked to return true
      const plugins = getPlugins()
      const cssPlugin = plugins.find((p) => p.name === "CssExtractRspackPlugin")
      expect(cssPlugin).toBeDefined()
    })

    test("cssExtractRspackPlugin forces emit in all environments", () => {
      moduleExists.mockReturnValue(true)

      const pluginsModule = require("../../../package/plugins/rspack")
      const plugins = pluginsModule.getPlugins()

      const cssPlugin = plugins.find((p) => p.name === "CssExtractRspackPlugin")
      expect(cssPlugin).toBeDefined()
      expect(cssPlugin.options.emit).toBe(true)
    })
  })
})
