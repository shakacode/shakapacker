/**
 * Tests for the rspack code paths in bundlerUtils.
 *
 * These tests mock the config module to set assets_bundler = "rspack",
 * then re-require bundlerUtils to exercise the rspack branches.
 */

// Mock requireOrError to provide a fake @rspack/core (v2 is pure ESM, can't be require()'d by Jest)
jest.mock("../../package/utils/requireOrError", () => {
  function CssExtractRspackPlugin(options) {
    this.options = options
  }
  CssExtractRspackPlugin.loader = "css-extract-rspack-loader"

  return {
    requireOrError: (moduleName) => {
      if (moduleName === "@rspack/core") {
        return {
          DefinePlugin: function DefinePlugin(definitions) {
            this.definitions = definitions
          },
          EnvironmentPlugin: function EnvironmentPlugin(env) {
            this.env = env
          },
          ProvidePlugin: function ProvidePlugin(definitions) {
            this.definitions = definitions
          },
          HotModuleReplacementPlugin: function HotModuleReplacementPlugin() {},
          ProgressPlugin: function ProgressPlugin() {},
          CssExtractRspackPlugin
        }
      }
      throw new Error(`Module ${moduleName} not found`)
    }
  }
})

let bundlerUtils

describe("bundlerUtils with rspack", () => {
  beforeAll(() => {
    // Mock config to return rspack as the bundler
    jest.mock("../../package/config", () => ({
      assets_bundler: "rspack",
      source_path: "app/javascript",
      source_entry_path: "packs",
      public_root_path: "public",
      public_output_path: "packs",
      cache_path: "tmp/shakapacker",
      shakapacker_precompile: true,
      webpack_compile_output: true,
      nested_entries: false,
      ensure_consistent_versioning: false,
      compiler_strategy: "default"
    }))

    // Clear any cached modules so bundlerUtils picks up the mock
    jest.resetModules()

    bundlerUtils = require("../../package/utils/bundlerUtils")
  })

  afterAll(() => {
    jest.restoreAllMocks()
    jest.resetModules()
  })

  describe("isRspack and isWebpack", () => {
    test("isRspack is true when assets_bundler is rspack", () => {
      expect(bundlerUtils.isRspack).toBe(true)
    })

    test("isWebpack is false when assets_bundler is rspack", () => {
      expect(bundlerUtils.isWebpack).toBe(false)
    })
  })

  describe("getBundler", () => {
    test("returns @rspack/core module", () => {
      const bundler = bundlerUtils.getBundler()
      expect(bundler).toBeDefined()
      expect(bundler.DefinePlugin).toBeDefined()
      expect(bundler.EnvironmentPlugin).toBeDefined()
      expect(bundler.ProvidePlugin).toBeDefined()
    })
  })

  describe("getCssExtractPlugin", () => {
    test("returns CssExtractRspackPlugin", () => {
      const CssPlugin = bundlerUtils.getCssExtractPlugin()
      expect(CssPlugin).toBeDefined()
      expect(CssPlugin.loader).toBeDefined()
    })
  })

  describe("getCssExtractPluginLoader", () => {
    test("returns a string loader path", () => {
      const loader = bundlerUtils.getCssExtractPluginLoader()
      expect(typeof loader).toBe("string")
    })

    test("returns the same loader as getCssExtractPlugin().loader", () => {
      const loader = bundlerUtils.getCssExtractPluginLoader()
      const plugin = bundlerUtils.getCssExtractPlugin()
      expect(loader).toBe(plugin.loader)
    })
  })

  describe("getDefinePlugin", () => {
    test("returns rspack DefinePlugin", () => {
      const DefinePlugin = bundlerUtils.getDefinePlugin()
      expect(DefinePlugin).toBeDefined()
      expect(DefinePlugin).toBeInstanceOf(Function)
    })
  })

  describe("getEnvironmentPlugin", () => {
    test("returns rspack EnvironmentPlugin", () => {
      const EnvironmentPlugin = bundlerUtils.getEnvironmentPlugin()
      expect(EnvironmentPlugin).toBeDefined()
      expect(EnvironmentPlugin).toBeInstanceOf(Function)
    })
  })

  describe("getProvidePlugin", () => {
    test("returns rspack ProvidePlugin", () => {
      const ProvidePlugin = bundlerUtils.getProvidePlugin()
      expect(ProvidePlugin).toBeDefined()
      expect(ProvidePlugin).toBeInstanceOf(Function)
    })
  })
})
