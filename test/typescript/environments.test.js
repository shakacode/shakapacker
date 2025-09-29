// Type-specific tests for environment modules
// Test imports to ensure TypeScript modules compile correctly
const developmentConfig = require("../../package/environments/development")
const productionConfig = require("../../package/environments/production")
const testConfig = require("../../package/environments/test")

describe("TypeScript Environment Modules", () => {
  describe("development.ts", () => {
    it("exports a valid webpack/rspack configuration", () => {
      expect(developmentConfig).toBeDefined()
      expect(typeof developmentConfig).toBe("object")
      expect(developmentConfig.mode).toBe("development")
    })

    it("includes proper devtool configuration", () => {
      expect(developmentConfig.devtool).toBe("cheap-module-source-map")
    })

    it("can be used as webpack configuration", () => {
      // This test verifies the module exports valid config
      const config = developmentConfig
      expect(config).toBeDefined()
      expect(typeof config).toBe("object")
    })
  })

  describe("production.ts", () => {
    it("exports a valid webpack/rspack configuration", () => {
      expect(productionConfig).toBeDefined()
      expect(typeof productionConfig).toBe("object")
      expect(productionConfig.mode).toBe("production")
    })

    it("includes proper devtool configuration", () => {
      expect(productionConfig.devtool).toBe("source-map")
    })

    it("includes optimization configuration", () => {
      expect(productionConfig.optimization).toBeDefined()
    })

    it("includes plugins array", () => {
      expect(Array.isArray(productionConfig.plugins)).toBe(true)
    })

    it("can be used as webpack configuration", () => {
      const config = productionConfig
      expect(config).toBeDefined()
      expect(typeof config).toBe("object")
    })
  })

  describe("test.ts", () => {
    it("exports a valid webpack/rspack configuration", () => {
      expect(testConfig).toBeDefined()
      expect(typeof testConfig).toBe("object")
    })

    it("includes proper mode configuration", () => {
      // Test environment should always have a mode defined
      expect(testConfig.mode).toBeDefined()
      expect(["development", "production", "test"]).toContain(testConfig.mode)
    })

    it("can be used as webpack configuration", () => {
      const config = testConfig
      expect(config).toBeDefined()
      expect(typeof config).toBe("object")
    })
  })

  describe("type safety", () => {
    it("ensures all environment configs have consistent base structure", () => {
      const configs = [developmentConfig, productionConfig, testConfig]

      configs.forEach((config) => {
        expect(config).toHaveProperty("module")
        expect(config).toHaveProperty("entry")
        expect(config).toHaveProperty("output")
        expect(config).toHaveProperty("resolve")
      })
    })

    it("validates dev server configuration when present", () => {
      // Development config may or may not have devServer depending on environment
      // When present, it should be properly configured
      const { devServer } = developmentConfig

      // DevServer should be defined in development config
      expect(devServer).toBeDefined()

      // If devServer exists, validate port property
      const validPort =
        !devServer ||
        devServer.port === undefined ||
        typeof devServer.port === "number" ||
        typeof devServer.port === "string" ||
        devServer.port === "auto"

      expect(validPort).toBe(true)
    })
  })
})
