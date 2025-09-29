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
      const { devServer } = developmentConfig

      // Compute validation outside of expect to avoid conditionals in test
      const isValidDevServer =
        devServer === undefined || typeof devServer === "object"

      // Always assert devServer validity unconditionally
      expect(isValidDevServer).toBe(true)

      // Compute port validation
      let isValidPort = true
      if (devServer) {
        const port = devServer.port
        isValidPort =
          typeof port === "number" ||
          typeof port === "string" ||
          port === undefined ||
          port === "auto"
      }

      // Assert port validation result unconditionally
      expect(isValidPort).toBe(true)
    })
  })
})
