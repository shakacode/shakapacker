/* eslint-disable func-names, jest/no-conditional-in-test */

const { chdirTestApp } = require("../../helpers")

const rootPath = process.cwd()
chdirTestApp()

// Mock config to ensure assets_bundler is set to rspack
jest.mock("../../../package/config", () => {
  const actual = jest.requireActual("../../../package/config")
  return {
    ...actual,
    assets_bundler: "rspack"
  }
})

// Mock helpers before requiring the rspack module
jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  const moduleExists = jest.fn(() => true)
  return {
    ...original,
    moduleExists
  }
})

// Mock validateDependencies to prevent actual validation
jest.mock("../../../package/utils/validateDependencies", () => ({
  validateRspackDependencies: jest.fn()
}))

// Mock requireOrError to provide a fake @rspack/core (v2 is pure ESM, can't be require()'d by Jest)
jest.mock("../../../package/utils/requireOrError", () => ({
  requireOrError: (moduleName) => {
    if (moduleName === "@rspack/core") {
      const CssExtractRspackPlugin = jest.fn(function (options) {
        this.options = options
      })
      CssExtractRspackPlugin.loader = "css-extract-rspack-loader"

      return {
        DefinePlugin: jest.fn(function (definitions) {
          this.definitions = definitions
        }),
        EnvironmentPlugin: jest.fn(function (env) {
          this.env = env
        }),
        ProvidePlugin: jest.fn(function (definitions) {
          this.definitions = definitions
        }),
        HotModuleReplacementPlugin: jest.fn(),
        ProgressPlugin: jest.fn(),
        CssExtractRspackPlugin,
        SubresourceIntegrityPlugin: jest.fn(function (options) {
          this.options = options
        }),
        SwcJsMinimizerRspackPlugin: jest.fn(),
        LightningCssMinimizerRspackPlugin: jest.fn()
      }
    }
    if (moduleName === "rspack-manifest-plugin") {
      return {
        RspackManifestPlugin: jest.fn(function (options) {
          this.options = options
        })
      }
    }
    return jest
      .requireActual("../../../package/utils/requireOrError")
      .requireOrError(moduleName)
  }
}))

describe("rspack/index", () => {
  let rspackIndex
  let validateRspackDependencies

  const loadRspackIndex = (nodeEnv = "development") => {
    const previousNodeEnv = process.env.NODE_ENV
    jest.resetModules()

    if (nodeEnv === undefined) {
      delete process.env.NODE_ENV
    } else {
      process.env.NODE_ENV = nodeEnv
    }

    const loadedRspackIndex = require("../../../package/rspack/index")
    const {
      validateRspackDependencies: loadedValidateRspackDependencies
    } = require("../../../package/utils/validateDependencies")

    if (previousNodeEnv === undefined) {
      delete process.env.NODE_ENV
    } else {
      process.env.NODE_ENV = previousNodeEnv
    }

    return {
      rspackIndex: loadedRspackIndex,
      validateRspackDependencies: loadedValidateRspackDependencies
    }
  }

  beforeEach(() => {
    ;({ rspackIndex, validateRspackDependencies } = loadRspackIndex())
  })

  afterAll(() => process.chdir(rootPath))

  describe("exports", () => {
    test("exports webpack-merge v5 functions", () => {
      expect(rspackIndex.merge).toBeInstanceOf(Function)
      expect(rspackIndex.mergeWithRules).toBeInstanceOf(Function)
      expect(rspackIndex.mergeWithCustomize).toBeInstanceOf(Function)
      expect(rspackIndex.unique).toBeInstanceOf(Function)
    })

    test("exports config object", () => {
      expect(rspackIndex.config).toHaveProperty("source_path")
      expect(rspackIndex.config).toHaveProperty("public_output_path")
    })

    test("exports devServer object", () => {
      expect(rspackIndex.devServer).toBeDefined()
    })

    test("exports generateRspackConfig function", () => {
      expect(rspackIndex.generateRspackConfig).toBeInstanceOf(Function)
    })

    test("exports baseConfig object", () => {
      expect(rspackIndex.baseConfig).toBeDefined()
      expect(rspackIndex.baseConfig).toHaveProperty("mode")
    })

    test("exports env object", () => {
      expect(rspackIndex.env).toHaveProperty("railsEnv")
      expect(rspackIndex.env).toHaveProperty("nodeEnv")
    })

    test("exports rules array", () => {
      expect(Array.isArray(rspackIndex.rules)).toBe(true)
      expect(rspackIndex.rules.length).toBeGreaterThan(0)
    })

    test("exports moduleExists function", () => {
      expect(typeof rspackIndex.moduleExists).toBe("function")
    })

    test("exports canProcess function", () => {
      expect(rspackIndex.canProcess).toBeInstanceOf(Function)
    })

    test("exports inliningCss value", () => {
      expect(typeof rspackIndex.inliningCss).toBe("boolean")
    })
  })

  describe("generateRspackConfig", () => {
    test("returns a valid rspack config object", () => {
      const config = rspackIndex.generateRspackConfig()

      expect(config).toBeDefined()
      expect(config).toHaveProperty("mode")
      expect(config).toHaveProperty("module")
      expect(config).toHaveProperty("plugins")
      expect(config).toHaveProperty("optimization")
    })

    test("returns a new top-level config object on each call", () => {
      const config1 = rspackIndex.generateRspackConfig()
      const config2 = rspackIndex.generateRspackConfig()

      expect(config1).not.toBe(config2)
      config1.newKey = "new value"

      expect(config2).not.toHaveProperty("newKey")
    })

    test("merges extra config", () => {
      const config = rspackIndex.generateRspackConfig({
        newKey: "new value",
        output: {
          path: "new path"
        }
      })

      expect(config).toHaveProperty("newKey", "new value")
      expect(config).toHaveProperty("output.path", "new path")
    })

    test("deep-merges development optimization overrides without losing shared defaults", () => {
      const config = rspackIndex.generateRspackConfig({
        optimization: { runtimeChunk: "multiple" }
      })

      expect(config).toHaveProperty("optimization.splitChunks.chunks", "all")
      expect(config).toHaveProperty("optimization.runtimeChunk", "multiple")
      expect(config.optimization).not.toHaveProperty("minimize")
    })

    test("includes module rules in config", () => {
      const config = rspackIndex.generateRspackConfig()

      expect(config.module).toBeDefined()
      expect(config.module.rules).toBeDefined()
      expect(Array.isArray(config.module.rules)).toBe(true)
      // The exact number of rules depends on which optional loaders are installed,
      // so we only verify that at least some rules exist
      expect(config.module.rules.length).toBeGreaterThan(0)
    })

    test("includes plugins in config", () => {
      const config = rspackIndex.generateRspackConfig()

      expect(config.plugins).toBeDefined()
      expect(Array.isArray(config.plugins)).toBe(true)
    })

    test("preserves development optimization defaults from the environment config", () => {
      const config = rspackIndex.generateRspackConfig()

      expect(config.optimization).toBeDefined()
      expect(config).toHaveProperty("optimization.splitChunks.chunks", "all")
      expect(config).toHaveProperty("optimization.runtimeChunk", "single")
      expect(config.optimization).not.toHaveProperty("minimize")
    })

    test("preserves production compression plugins and minimizers", () => {
      const { rspackIndex: productionRspackIndex } = loadRspackIndex("production")
      const config = productionRspackIndex.generateRspackConfig({
        optimization: { runtimeChunk: "multiple" }
      })
      const compressionPlugins = config.plugins.filter(
        (plugin) => plugin.constructor?.name === "CompressionPlugin"
      )

      expect(config).toHaveProperty("optimization.splitChunks.chunks", "all")
      expect(config).toHaveProperty("optimization.runtimeChunk", "multiple")
      expect(config).toHaveProperty("optimization.minimize", true)
      expect(config.optimization.minimizer).toHaveLength(2)
      expect(compressionPlugins).toHaveLength("brotli" in process.versions ? 2 : 1)
    })

    test("errors if multiple configs are provided", () => {
      expect(() => rspackIndex.generateRspackConfig({}, {})).toThrow(
        "use webpack-merge to merge configs before passing them to Shakapacker"
      )
    })

    test("validates rspack dependencies on generation", () => {
      rspackIndex.generateRspackConfig()
      expect(validateRspackDependencies).toHaveBeenCalledTimes(1)
    })
  })

  describe("rules", () => {
    test("includes JavaScript/JSX rule with builtin:swc-loader", () => {
      const jsRule = rspackIndex.rules.find(
        (rule) => rule.test && rule.test.toString().includes("js|jsx|mjs")
      )

      expect(jsRule).toBeDefined()
      expect(jsRule.type).toBe("javascript/auto")
      expect(jsRule.use).toBeDefined()
      expect(Array.isArray(jsRule.use)).toBe(true)
      expect(jsRule.use[0].loader).toBe("builtin:swc-loader")
    })

    test("includes TypeScript rule with builtin:swc-loader", () => {
      const tsRule = rspackIndex.rules.find(
        (rule) => rule.test && rule.test.toString().includes("ts|tsx")
      )

      expect(tsRule).toBeDefined()
      expect(tsRule.type).toBe("javascript/auto")
      expect(tsRule.use).toBeDefined()
      expect(Array.isArray(tsRule.use)).toBe(true)
      expect(tsRule.use[0].loader).toBe("builtin:swc-loader")
    })

    test("includes file/asset handling rule", () => {
      const fileRule = rspackIndex.rules.find(
        (rule) =>
          rule.test &&
          (rule.test.toString().includes("png") ||
            rule.test.toString().includes("jpg") ||
            rule.test.toString().includes("svg"))
      )

      expect(fileRule).toBeDefined()
    })

    test("includes raw file loading rule", () => {
      const rawRule = rspackIndex.rules.find(
        (rule) => rule.type === "asset/source"
      )

      expect(rawRule).toBeDefined()
    })
  })

  describe("helper functions", () => {
    test("moduleExists returns boolean", () => {
      const result = rspackIndex.moduleExists("some-module")
      expect(typeof result).toBe("boolean")
    })

    test("canProcess invokes callback when module resolves", () => {
      const callback = jest.fn((modulePath) => ({
        processed: true,
        path: modulePath
      }))
      const result = rspackIndex.canProcess("path", callback)

      expect(callback).toHaveBeenCalledWith(expect.any(String))
      expect(result).toHaveProperty("processed", true)
      expect(result).toHaveProperty("path")
    })

    test("canProcess returns null and does not invoke callback when module is missing", () => {
      const callback = jest.fn()
      const result = rspackIndex.canProcess(
        "__definitely_not_a_real_package_name__",
        callback
      )

      expect(result).toBeNull()
      expect(callback).not.toHaveBeenCalled()
    })
  })

  describe("environment integration", () => {
    test("uses correct environment config based on NODE_ENV", () => {
      const config = rspackIndex.generateRspackConfig()
      const { nodeEnv } = rspackIndex.env

      const expectedMode =
        nodeEnv === "production" ? "production" : "development"
      expect(config.mode).toBe(expectedMode)
    })
  })
})
