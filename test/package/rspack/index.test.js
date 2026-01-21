const { chdirTestApp, resetEnv } = require("../../helpers")

const rootPath = process.cwd()
chdirTestApp()

jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  const moduleExists = () => false
  return {
    ...original,
    moduleExists
  }
})

jest.mock("../../../package/utils/validateDependencies", () => {
  const original = jest.requireActual(
    "../../../package/utils/validateDependencies"
  )
  return {
    ...original,
    validateRspackDependencies: () => {
      // Mock to skip dependency validation in tests
    }
  }
})

describe("rspack/index", () => {
  beforeEach(() => {
    jest.resetModules()
    resetEnv()
    process.env.SHAKAPACKER_ASSETS_BUNDLER = "rspack"
  })
  afterAll(() => process.chdir(rootPath))

  test("exports webpack-merge v5 functions", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.merge).toBeInstanceOf(Function)
    expect(rspack.mergeWithRules).toBeInstanceOf(Function)
    expect(rspack.mergeWithCustomize).toBeInstanceOf(Function)
    expect(rspack.unique).toBeInstanceOf(Function)
  })

  test("exports config object", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.config).toBeDefined()
    expect(rspack.config).toHaveProperty("source_path")
    expect(rspack.config).toHaveProperty("public_output_path")
  })

  test("exports devServer object", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.devServer).toBeDefined()
    expect(typeof rspack.devServer).toBe("object")
  })

  test("exports env object", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.env).toBeDefined()
    expect(rspack.env).toHaveProperty("nodeEnv")
    expect(rspack.env).toHaveProperty("railsEnv")
  })

  test("exports rules array", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.rules).toBeDefined()
    expect(Array.isArray(rspack.rules)).toBe(true)
  })

  test("exports baseConfig object", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.baseConfig).toBeDefined()
    expect(typeof rspack.baseConfig).toBe("object")
    expect(rspack.baseConfig).toHaveProperty("output")
    expect(rspack.baseConfig).toHaveProperty("resolve")
  })

  test("exports utility functions", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.moduleExists).toBeInstanceOf(Function)
    expect(rspack.canProcess).toBeInstanceOf(Function)
    expect(rspack.inliningCss).toBeDefined()
  })

  test("exports generateRspackConfig function", () => {
    const rspack = require("../../../package/rspack/index")
    expect(rspack.generateRspackConfig).toBeInstanceOf(Function)
  })

  test("generateRspackConfig returns an immutable object", () => {
    const { generateRspackConfig } = require("../../../package/rspack/index")

    const rspackConfig1 = generateRspackConfig()
    const rspackConfig2 = generateRspackConfig()

    rspackConfig1.newKey = "new value"
    rspackConfig1.output.path = "new path"

    expect(rspackConfig2).not.toHaveProperty("newKey")
    expect(rspackConfig2.output.path).not.toBe("new path")
  })

  test("generateRspackConfig merges extra config", () => {
    const { generateRspackConfig } = require("../../../package/rspack/index")

    const rspackConfig = generateRspackConfig({
      newKey: "new value",
      output: {
        path: "new path"
      }
    })

    expect(rspackConfig).toHaveProperty("newKey", "new value")
    expect(rspackConfig).toHaveProperty("output.path", "new path")
    expect(rspackConfig).toHaveProperty("output.publicPath", "/packs/")
  })

  test("generateRspackConfig errors if multiple configs are provided", () => {
    const { generateRspackConfig } = require("../../../package/rspack/index")

    expect(() => generateRspackConfig({}, {})).toThrow(
      "use webpack-merge to merge configs before passing them to Shakapacker"
    )
  })

  test("generateRspackConfig includes plugins", () => {
    const { generateRspackConfig } = require("../../../package/rspack/index")

    const rspackConfig = generateRspackConfig()

    expect(rspackConfig).toHaveProperty("plugins")
    expect(Array.isArray(rspackConfig.plugins)).toBe(true)
  })

  test("generateRspackConfig includes optimization", () => {
    const { generateRspackConfig } = require("../../../package/rspack/index")

    const rspackConfig = generateRspackConfig()

    expect(rspackConfig).toHaveProperty("optimization")
    expect(typeof rspackConfig.optimization).toBe("object")
  })

  test("generateRspackConfig includes module rules", () => {
    const { generateRspackConfig } = require("../../../package/rspack/index")

    const rspackConfig = generateRspackConfig()

    expect(rspackConfig).toHaveProperty("module")
    expect(rspackConfig.module).toHaveProperty("rules")
    expect(Array.isArray(rspackConfig.module.rules)).toBe(true)
  })

  test("generateRspackConfig respects NODE_ENV for environment config", () => {
    process.env.NODE_ENV = "production"
    jest.resetModules()

    const { generateRspackConfig } = require("../../../package/rspack/index")
    const rspackConfig = generateRspackConfig()

    expect(rspackConfig).toHaveProperty("mode", "production")
  })

  test("generateRspackConfig uses base config when environment config not found", () => {
    process.env.NODE_ENV = "custom-env-that-does-not-exist"
    jest.resetModules()

    const { generateRspackConfig } = require("../../../package/rspack/index")

    // Should not throw, should use baseConfig
    expect(() => generateRspackConfig()).not.toThrow()

    const rspackConfig = generateRspackConfig()
    expect(rspackConfig).toHaveProperty("output")
    expect(rspackConfig).toHaveProperty("resolve")
  })

  test("generateRspackConfig merges environment config with extra config", () => {
    process.env.NODE_ENV = "development"
    jest.resetModules()

    const { generateRspackConfig } = require("../../../package/rspack/index")

    const rspackConfig = generateRspackConfig({
      devtool: "custom-source-map"
    })

    expect(rspackConfig).toHaveProperty("devtool", "custom-source-map")
    expect(rspackConfig).toHaveProperty("mode", "development")
  })
})
