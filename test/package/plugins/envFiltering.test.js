/**
 * Security tests for environment variable filtering in EnvironmentPlugin.
 *
 * These tests verify that only allowlisted environment variables are exposed
 * to client-side JavaScript bundles, preventing accidental leakage of secrets.
 *
 * CVE: Environment variables leak via EnvironmentPlugin(process.env)
 * See: https://github.com/shakacode/shakapacker/security/advisories
 */

const fs = require("fs")
const path = require("path")

const pluginsDir = path.resolve(__dirname, "../../../package/plugins")

describe("environment variable filtering security", () => {
  const originalEnv = { ...process.env }

  beforeEach(() => {
    // Set up test environment with sensitive variables
    process.env.NODE_ENV = "production"
    process.env.RAILS_ENV = "production"
    process.env.WEBPACK_SERVE = "false"

    // Simulate sensitive build environment variables
    process.env.DATABASE_URL = "postgres://user:password@host/db"
    process.env.AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
    process.env.AWS_SECRET_ACCESS_KEY =
      "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    process.env.RAILS_MASTER_KEY = "abc123secretmasterkey456"
    process.env.STRIPE_SECRET_KEY = "sk_live_secretkey123"
    process.env.SESSION_SECRET = "supersecrettoken"

    // Clear any cached modules
    jest.resetModules()
  })

  afterEach(() => {
    // Restore original environment
    Object.keys(process.env).forEach((key) => {
      if (!(key in originalEnv)) {
        delete process.env[key]
      }
    })
    Object.assign(process.env, originalEnv)
    delete process.env.SHAKAPACKER_ENV_VARS
  })

  describe("shared envFilter module", () => {
    it("exists and exports the filtering functions", () => {
      const envFilterSource = fs.readFileSync(
        path.join(pluginsDir, "envFilter.ts"),
        "utf8"
      )

      // Verify exports
      expect(envFilterSource).toContain("export const DEFAULT_ALLOWED_ENV_VARS")
      expect(envFilterSource).toContain("export const getAllowedEnvVars")
      expect(envFilterSource).toContain("export const getFilteredEnv")
    })

    it("has the default allowlist with only safe variables", () => {
      const envFilterSource = fs.readFileSync(
        path.join(pluginsDir, "envFilter.ts"),
        "utf8"
      )

      // Extract the DEFAULT_ALLOWED_ENV_VARS array from source
      const allowlistMatch = envFilterSource.match(
        /DEFAULT_ALLOWED_ENV_VARS\s*=\s*\[([\s\S]*?)\]\s*as const/
      )
      expect(allowlistMatch).toBeTruthy()

      const allowlistContent = allowlistMatch[1]

      // These patterns should NEVER appear in the allowlist
      const sensitivePatterns = [
        "DATABASE",
        "SECRET",
        "PASSWORD",
        "CREDENTIAL",
        "AWS_",
        "STRIPE",
        "MASTER"
      ]

      sensitivePatterns.forEach((pattern) => {
        expect(allowlistContent.toUpperCase()).not.toContain(pattern)
      })

      // Verify expected safe vars are present
      expect(allowlistContent).toContain("NODE_ENV")
      expect(allowlistContent).toContain("RAILS_ENV")
      expect(allowlistContent).toContain("WEBPACK_SERVE")
    })

    it("includes SHAKAPACKER_ENV_VARS extension support", () => {
      const envFilterSource = fs.readFileSync(
        path.join(pluginsDir, "envFilter.ts"),
        "utf8"
      )

      expect(envFilterSource).toContain("SHAKAPACKER_ENV_VARS")
      expect(envFilterSource).toContain('split(",")')
    })

    it("exports PUBLIC_ENV_PREFIX constant", () => {
      const envFilterSource = fs.readFileSync(
        path.join(pluginsDir, "envFilter.ts"),
        "utf8"
      )

      expect(envFilterSource).toContain("export const PUBLIC_ENV_PREFIX")
      expect(envFilterSource).toContain('SHAKAPACKER_PUBLIC_"')
    })

    it("auto-exposes SHAKAPACKER_PUBLIC_* variables", () => {
      const envFilterSource = fs.readFileSync(
        path.join(pluginsDir, "envFilter.ts"),
        "utf8"
      )

      // Verify the prefix check is present
      expect(envFilterSource).toContain("startsWith(PUBLIC_ENV_PREFIX)")
      expect(envFilterSource).toContain("Object.keys(process.env)")
    })

    it("handles whitespace and empty values in CSV", () => {
      const envFilterSource = fs.readFileSync(
        path.join(pluginsDir, "envFilter.ts"),
        "utf8"
      )

      // Verify trim() is called on each value
      expect(envFilterSource).toMatch(/\.map\(\s*\(?v\)?\s*=>\s*v\.trim\(\)/)
      // Verify filter(Boolean) is called to remove empty strings
      expect(envFilterSource).toMatch(/\.filter\(Boolean\)/)
    })
  })

  describe("webpack plugin", () => {
    it("imports from shared envFilter module", () => {
      const webpackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "webpack.ts"),
        "utf8"
      )

      expect(webpackPluginSource).toContain(
        'import { getFilteredEnv } from "./envFilter"'
      )
    })

    it("uses getFilteredEnv() not process.env", () => {
      const webpackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "webpack.ts"),
        "utf8"
      )

      // SECURITY: Verify the dangerous pattern is NOT present
      expect(webpackPluginSource).not.toMatch(
        /new webpack\.EnvironmentPlugin\(process\.env\)/
      )

      // Verify the safe pattern IS present
      expect(webpackPluginSource).toMatch(/getFilteredEnv\(\)/)
    })

    it("does not duplicate the filtering logic", () => {
      const webpackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "webpack.ts"),
        "utf8"
      )

      // Should NOT have its own copy of these
      expect(webpackPluginSource).not.toContain("DEFAULT_ALLOWED_ENV_VARS")
      expect(webpackPluginSource).not.toContain("PUBLIC_ENV_PREFIX")
      expect(webpackPluginSource).not.toContain("getAllowedEnvVars")
    })
  })

  describe("rspack plugin", () => {
    it("imports from shared envFilter module", () => {
      const rspackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "rspack.ts"),
        "utf8"
      )

      expect(rspackPluginSource).toContain(
        'import { getFilteredEnv } from "./envFilter"'
      )
    })

    it("uses getFilteredEnv() not process.env", () => {
      const rspackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "rspack.ts"),
        "utf8"
      )

      // SECURITY: Verify the dangerous pattern is NOT present
      expect(rspackPluginSource).not.toMatch(
        /new rspack\.EnvironmentPlugin\(process\.env\)/
      )

      // Verify the safe pattern IS present
      expect(rspackPluginSource).toMatch(/getFilteredEnv\(\)/)
    })

    it("does not duplicate the filtering logic", () => {
      const rspackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "rspack.ts"),
        "utf8"
      )

      // Should NOT have its own copy of these
      expect(rspackPluginSource).not.toContain("DEFAULT_ALLOWED_ENV_VARS")
      expect(rspackPluginSource).not.toContain("PUBLIC_ENV_PREFIX")
      expect(rspackPluginSource).not.toContain("getAllowedEnvVars")
    })
  })

  describe("consistency", () => {
    it("both plugins use the same shared module", () => {
      const webpackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "webpack.ts"),
        "utf8"
      )
      const rspackPluginSource = fs.readFileSync(
        path.join(pluginsDir, "rspack.ts"),
        "utf8"
      )

      // Both should import from the same source
      const webpackImport = webpackPluginSource.match(
        /import\s*{[^}]*getFilteredEnv[^}]*}\s*from\s*["']([^"']+)["']/
      )
      const rspackImport = rspackPluginSource.match(
        /import\s*{[^}]*getFilteredEnv[^}]*}\s*from\s*["']([^"']+)["']/
      )

      expect(webpackImport).toBeTruthy()
      expect(rspackImport).toBeTruthy()
      expect(webpackImport[1]).toBe(rspackImport[1])
    })
  })
})
