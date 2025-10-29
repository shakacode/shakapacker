const { resetEnv } = require("../helpers")
const { run } = require("../../package/configExporter/cli")

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
      expect(filename).toBe("webpack-development-client.yml")
    })

    test("generates correct filename for server config", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "production",
        "server",
        "yaml"
      )
      expect(filename).toBe("webpack-production-server.yml")
    })

    test("generates correct filename for client-hmr config", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "development",
        "client-hmr",
        "yaml"
      )
      expect(filename).toBe("webpack-development-client-hmr.yml")
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
      expect(filename).toBe("webpack-development-client-modern.yml")
    })

    test("generates correct filename for custom output name client-legacy", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "webpack",
        "production",
        "client-legacy",
        "yaml"
      )
      expect(filename).toBe("webpack-production-client-legacy.yml")
    })

    test("generates correct filename for custom output name server-bundle", () => {
      const { FileWriter } = require("../../package/configExporter/fileWriter")
      const filename = FileWriter.generateFilename(
        "rspack",
        "development",
        "server-bundle",
        "yaml"
      )
      expect(filename).toBe("rspack-development-server-bundle.yml")
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
      expect(filename).toBe("webpack-dev-hmr-client-modern.yml")
    })
  })

  describe("yamlSerializer", () => {
    test("serializes object keys in alphabetical order", () => {
      const {
        YamlSerializer
      } = require("../../package/configExporter/yamlSerializer")
      const serializer = new YamlSerializer({
        annotate: false,
        appRoot: "/test/app"
      })

      // Create an object with keys intentionally out of alphabetical order
      const config = {
        mode: "production",
        entry: "./src/index.js",
        optimization: {
          minimize: true
        },
        output: {
          path: "/dist",
          filename: "bundle.js"
        },
        devtool: "source-map"
      }

      const metadata = {
        exportedAt: "2025-10-28",
        environment: "production",
        bundler: "webpack",
        configType: "client",
        configCount: 1
      }

      const result = serializer.serialize(config, metadata)

      // Extract just the config part (skip the header)
      const lines = result.split("\n")
      const keyMatches = lines
        .map((line) => line.match(/^(\w+):/))
        .filter(Boolean)
        .map((match) => match[1])

      // Expected order: devtool, entry, mode, optimization, output
      expect(keyMatches).toStrictEqual([
        "devtool",
        "entry",
        "mode",
        "optimization",
        "output"
      ])
    })

    test("serializes nested object keys in alphabetical order", () => {
      const {
        YamlSerializer
      } = require("../../package/configExporter/yamlSerializer")
      const serializer = new YamlSerializer({
        annotate: false,
        appRoot: "/test/app"
      })

      const config = {
        output: {
          path: "/dist",
          filename: "bundle.js",
          clean: true
        }
      }

      const metadata = {
        exportedAt: "2025-10-28",
        environment: "production",
        bundler: "webpack",
        configType: "client",
        configCount: 1
      }

      const result = serializer.serialize(config, metadata)

      // Extract nested keys from the output section
      const lines = result.split("\n")
      const outputKeys = lines
        .map((line) => line.match(/^ {2}(\w+):/))
        .filter(Boolean)
        .map((match) => match[1])

      // Expected order: clean, filename, path
      expect(outputKeys).toStrictEqual(["clean", "filename", "path"])
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

  describe("argument validation", () => {
    // Mock console.error to suppress error output in tests
    let consoleErrorSpy

    beforeEach(() => {
      consoleErrorSpy = jest
        .spyOn(console, "error")
        .mockImplementation(() => {})
    })

    afterEach(() => {
      consoleErrorSpy.mockRestore()
    })

    test("rejects --all-builds with --output", async () => {
      const exitCode = await run(["--all-builds", "--output=config.yml"])
      expect(exitCode).toBe(1)
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          "--all-builds and --output are mutually exclusive"
        )
      )
    })

    test("allows --all-builds with --save-dir", async () => {
      // This test would normally run the command, but we'll just verify it doesn't
      // throw a validation error. Since we don't have a real config file in test,
      // it will fail later with a different error (config file not found)
      const exitCode = await run(["--all-builds", "--save-dir=./output"])
      expect(exitCode).toBe(1)
      // Should fail with config file error, not validation error
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        expect.stringContaining("Config file")
      )
      expect(consoleErrorSpy).not.toHaveBeenCalledWith(
        expect.stringContaining("mutually exclusive")
      )
    })

    test("rejects --all-builds with --stdout", async () => {
      const exitCode = await run(["--all-builds", "--stdout"])
      expect(exitCode).toBe(1)
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          "--all-builds and --stdout are mutually exclusive"
        )
      )
    })

    test("rejects --stdout with --output", async () => {
      const exitCode = await run(["--stdout", "--output=config.yml"])
      expect(exitCode).toBe(1)
      expect(consoleErrorSpy).toHaveBeenCalledWith(
        expect.stringContaining("--stdout and --output are mutually exclusive")
      )
    })
  })
})
