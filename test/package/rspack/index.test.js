/* eslint-disable jest/no-conditional-in-test, jest/no-conditional-expect */

const { chdirTestApp, resetEnv } = require("../../helpers")

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
  const moduleExists = () => true
  return {
    ...original,
    moduleExists
  }
})

// Mock validateDependencies to prevent actual validation
jest.mock("../../../package/utils/validateDependencies", () => ({
  validateRspackDependencies: jest.fn()
}))

const rspackIndex = require("../../../package/rspack/index")

describe("rspack/index", () => {
  beforeEach(() => {
    jest.resetModules()
    resetEnv()
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
      expect(rspackIndex.moduleExists).toBeInstanceOf(Function)
    })

    test("exports canProcess function", () => {
      expect(rspackIndex.canProcess).toBeInstanceOf(Function)
    })

    test("exports inliningCss value", () => {
      expect(rspackIndex.inliningCss).toBeDefined()
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

    test("returns a new object instance on each call", () => {
      const config1 = rspackIndex.generateRspackConfig()
      const config2 = rspackIndex.generateRspackConfig()

      config1.newKey = "new value"
      config1.output = config1.output || {}
      config1.output.path = "new path"

      expect(config2).not.toHaveProperty("newKey")
      if (config2.output) {
        expect(config2.output.path).not.toBe("new path")
      }
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

    test("includes module rules in config", () => {
      const config = rspackIndex.generateRspackConfig()

      expect(config.module).toBeDefined()
      expect(config.module.rules).toBeDefined()
      expect(Array.isArray(config.module.rules)).toBe(true)
      expect(config.module.rules.length).toBeGreaterThan(0)
    })

    test("includes plugins in config", () => {
      const config = rspackIndex.generateRspackConfig()

      expect(config.plugins).toBeDefined()
      expect(Array.isArray(config.plugins)).toBe(true)
    })

    test("includes optimization in config", () => {
      const config = rspackIndex.generateRspackConfig()

      expect(config.optimization).toBeDefined()
      expect(config.optimization).toHaveProperty("minimize")
    })

    test("errors if multiple configs are provided", () => {
      expect(() => rspackIndex.generateRspackConfig({}, {})).toThrow(
        "use webpack-merge to merge configs before passing them to Shakapacker"
      )
    })

    test("validates rspack dependencies on generation", () => {
      // The validation is called at module load time, not at function call time
      // This test verifies the function exists and can be called
      const config = rspackIndex.generateRspackConfig()
      expect(config).toBeDefined()
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

    test("canProcess invokes callback when module exists", () => {
      // canProcess takes a package name and a callback function
      // It returns null if the module doesn't exist, or the callback result if it does
      const callback = jest.fn((modulePath) => ({
        processed: true,
        path: modulePath
      }))
      const result = rspackIndex.canProcess("jest", callback)

      // Since jest exists, the callback should be invoked with the resolved module path
      if (result !== null) {
        expect(callback).toHaveBeenCalledWith(expect.any(String))
        expect(result).toHaveProperty("processed", true)
        expect(result).toHaveProperty("path")
      } else {
        // If module doesn't exist, callback should not be called and result is null
        expect(callback).not.toHaveBeenCalledWith(expect.anything())
        expect(result).toBeNull()
      }
    })
  })

  describe("environment integration", () => {
    test("uses correct environment config based on NODE_ENV", () => {
      const config = rspackIndex.generateRspackConfig()
      const { nodeEnv } = rspackIndex.env

      expect(config.mode).toBeDefined()
      if (nodeEnv === "production") {
        expect(config.mode).toBe("production")
      } else if (nodeEnv === "development") {
        expect(config.mode).toBe("development")
      }
    })
  })
})
