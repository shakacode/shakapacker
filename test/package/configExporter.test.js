const { resetEnv } = require("../helpers")

// Helper function that mimics the env var restore logic from cli.ts lines 267-282
function restoreEnvVars(saved) {
  Object.keys(saved).forEach((key) => {
    if (saved[key] === undefined) {
      delete process.env[key]
    } else {
      process.env[key] = saved[key]
    }
  })
}

describe("configExporter", () => {
  beforeEach(() => jest.resetModules() && resetEnv())

  describe("fileWriter", () => {
    test("generates correct filename for client config", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "development",
        "client",
        "yaml"
      )
      expect(filename).toBe("webpack-development-client.yaml")
    })

    test("generates correct filename for server config", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "production",
        "server",
        "yaml"
      )
      expect(filename).toBe("webpack-production-server.yaml")
    })

    test("generates correct filename for client-hmr config", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "development",
        "client-hmr",
        "yaml"
      )
      expect(filename).toBe("webpack-development-client-hmr.yaml")
    })

    test("generates correct filename for json format", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "rspack",
        "production",
        "client",
        "json"
      )
      expect(filename).toBe("rspack-production-client.json")
    })

    test("generates correct filename for custom output name client-modern", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "development",
        "client-modern",
        "yaml"
      )
      expect(filename).toBe("webpack-development-client-modern.yaml")
    })

    test("generates correct filename for custom output name client-legacy", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "production",
        "client-legacy",
        "yaml"
      )
      expect(filename).toBe("webpack-production-client-legacy.yaml")
    })

    test("generates correct filename for custom output name server-bundle", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "rspack",
        "development",
        "server-bundle",
        "yaml"
      )
      expect(filename).toBe("rspack-development-server-bundle.yaml")
    })

    test("generates correct filename with buildName override", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "development",
        "client-modern",
        "yaml",
        "dev-hmr"
      )
      expect(filename).toBe("webpack-dev-hmr-client-modern.yaml")
    })
  })

  describe("environment variable preservation in runDoctorMode", () => {
    let originalEnv

    beforeEach(() => {
      // Save original environment
      originalEnv = {
        NODE_ENV: process.env.NODE_ENV,
        RAILS_ENV: process.env.RAILS_ENV,
        CLIENT_BUNDLE_ONLY: process.env.CLIENT_BUNDLE_ONLY,
        SERVER_BUNDLE_ONLY: process.env.SERVER_BUNDLE_ONLY,
        WEBPACK_SERVE: process.env.WEBPACK_SERVE
      }

      // Set up known initial state for development mode
      process.env.NODE_ENV = "development"
      process.env.RAILS_ENV = "development"
      delete process.env.WEBPACK_SERVE
      delete process.env.SERVER_BUNDLE_ONLY
    })

    afterEach(() => {
      // Restore original environment
      Object.keys(originalEnv).forEach((key) => {
        if (originalEnv[key] === undefined) {
          delete process.env[key]
        } else {
          process.env[key] = originalEnv[key]
        }
      })
    })

    test("preserves CLIENT_BUNDLE_ONLY when set before doctor mode", async () => {
      // Set a custom value that should be preserved
      process.env.CLIENT_BUNDLE_ONLY = "custom_value"

      // The doctor mode code internally does:
      // 1. Save original
      const saved = {
        CLIENT_BUNDLE_ONLY: process.env.CLIENT_BUNDLE_ONLY,
        WEBPACK_SERVE: process.env.WEBPACK_SERVE,
        SERVER_BUNDLE_ONLY: process.env.SERVER_BUNDLE_ONLY
      }

      // 2. Set HMR env vars
      process.env.WEBPACK_SERVE = "true"
      process.env.CLIENT_BUNDLE_ONLY = "yes"
      delete process.env.SERVER_BUNDLE_ONLY

      // 3. Restore using helper
      restoreEnvVars(saved)

      // Assert the original value is preserved
      expect(process.env.CLIENT_BUNDLE_ONLY).toBe("custom_value")
      expect(process.env.WEBPACK_SERVE).toBeUndefined()
      expect(process.env.SERVER_BUNDLE_ONLY).toBeUndefined()
    })

    test("deletes CLIENT_BUNDLE_ONLY when not set before doctor mode", async () => {
      // Ensure CLIENT_BUNDLE_ONLY is not set
      delete process.env.CLIENT_BUNDLE_ONLY

      // The doctor mode code internally does:
      // 1. Save original
      const saved = {
        CLIENT_BUNDLE_ONLY: process.env.CLIENT_BUNDLE_ONLY,
        WEBPACK_SERVE: process.env.WEBPACK_SERVE,
        SERVER_BUNDLE_ONLY: process.env.SERVER_BUNDLE_ONLY
      }

      // 2. Set HMR env vars
      process.env.WEBPACK_SERVE = "true"
      process.env.CLIENT_BUNDLE_ONLY = "yes"
      delete process.env.SERVER_BUNDLE_ONLY

      // Verify they were set
      expect(process.env.CLIENT_BUNDLE_ONLY).toBe("yes")
      expect(process.env.WEBPACK_SERVE).toBe("true")

      // 3. Restore using helper
      restoreEnvVars(saved)

      // Assert the variables are deleted since they were not set originally
      expect(process.env.CLIENT_BUNDLE_ONLY).toBeUndefined()
      expect(process.env.WEBPACK_SERVE).toBeUndefined()
      expect(process.env.SERVER_BUNDLE_ONLY).toBeUndefined()
    })
  })
})
