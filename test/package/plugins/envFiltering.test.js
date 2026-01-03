/**
 * Security tests for environment variable filtering in EnvironmentPlugin.
 *
 * These tests verify that only allowlisted environment variables are exposed
 * to client-side JavaScript bundles, preventing accidental leakage of secrets.
 *
 * CVE: Environment variables leak via EnvironmentPlugin(process.env)
 * See: https://github.com/shakacode/shakapacker/security/advisories
 */

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
    process.env.AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
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

  describe("webpack plugin", () => {
    it("only exposes allowlisted environment variables", () => {
      // Read the TypeScript source file to verify the implementation
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )

      // SECURITY: Verify the dangerous pattern is NOT present
      expect(webpackPluginSource).not.toMatch(
        /new webpack\.EnvironmentPlugin\(process\.env\)/
      )

      // Verify the safe pattern IS present
      expect(webpackPluginSource).toMatch(/getFilteredEnv\(\)/)
      expect(webpackPluginSource).toMatch(/DEFAULT_ALLOWED_ENV_VARS/)
    })

    it("does not include sensitive variable names in the default allowlist", () => {
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )

      // These patterns should NEVER appear in the allowlist
      const sensitivePatterns = [
        "DATABASE",
        "SECRET",
        "PASSWORD",
        "KEY",
        "TOKEN",
        "CREDENTIAL",
        "AWS_",
        "STRIPE",
        "MASTER"
      ]

      // Extract the DEFAULT_ALLOWED_ENV_VARS array from source
      const allowlistMatch = webpackPluginSource.match(
        /DEFAULT_ALLOWED_ENV_VARS\s*=\s*\[([\s\S]*?)\]\s*as const/
      )
      expect(allowlistMatch).toBeTruthy()

      const allowlistContent = allowlistMatch[1]

      sensitivePatterns.forEach((pattern) => {
        expect(allowlistContent.toUpperCase()).not.toContain(pattern)
      })
    })
  })

  describe("rspack plugin", () => {
    it("only exposes allowlisted environment variables", () => {
      const rspackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/rspack.ts"),
        "utf8"
      )

      // SECURITY: Verify the dangerous pattern is NOT present
      expect(rspackPluginSource).not.toMatch(
        /new rspack\.EnvironmentPlugin\(process\.env\)/
      )

      // Verify the safe pattern IS present
      expect(rspackPluginSource).toMatch(/getFilteredEnv\(\)/)
      expect(rspackPluginSource).toMatch(/DEFAULT_ALLOWED_ENV_VARS/)
    })

    it("does not include sensitive variable names in the default allowlist", () => {
      const rspackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/rspack.ts"),
        "utf8"
      )

      // These patterns should NEVER appear in the allowlist
      const sensitivePatterns = [
        "DATABASE",
        "SECRET",
        "PASSWORD",
        "KEY",
        "TOKEN",
        "CREDENTIAL",
        "AWS_",
        "STRIPE",
        "MASTER"
      ]

      // Extract the DEFAULT_ALLOWED_ENV_VARS array from source
      const allowlistMatch = rspackPluginSource.match(
        /DEFAULT_ALLOWED_ENV_VARS\s*=\s*\[([\s\S]*?)\]\s*as const/
      )
      expect(allowlistMatch).toBeTruthy()

      const allowlistContent = allowlistMatch[1]

      sensitivePatterns.forEach((pattern) => {
        expect(allowlistContent.toUpperCase()).not.toContain(pattern)
      })
    })
  })

  describe("shakapacker_ENV_VARS extension", () => {
    it("webpack plugin source includes SHAKAPACKER_ENV_VARS support", () => {
      // Read the TypeScript source file to verify the implementation
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )

      expect(webpackPluginSource).toContain("SHAKAPACKER_ENV_VARS")
      expect(webpackPluginSource).toContain('split(",")')
    })

    it("rspack plugin source includes SHAKAPACKER_ENV_VARS support", () => {
      // Read the TypeScript source file to verify the implementation
      const rspackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/rspack.ts"),
        "utf8"
      )

      expect(rspackPluginSource).toContain("SHAKAPACKER_ENV_VARS")
      expect(rspackPluginSource).toContain('split(",")')
    })
  })

  describe("consistency between webpack and rspack plugins", () => {
    it("both plugins use the same default allowlist", () => {
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )
      const rspackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/rspack.ts"),
        "utf8"
      )

      // Extract allowlists from both files
      const webpackAllowlist = webpackPluginSource.match(
        /DEFAULT_ALLOWED_ENV_VARS\s*=\s*\[([\s\S]*?)\]\s*as const/
      )[1]
      const rspackAllowlist = rspackPluginSource.match(
        /DEFAULT_ALLOWED_ENV_VARS\s*=\s*\[([\s\S]*?)\]\s*as const/
      )[1]

      // Normalize whitespace for comparison
      const normalizeAllowlist = (str) =>
        str.replace(/\s+/g, " ").trim()

      expect(normalizeAllowlist(webpackAllowlist)).toBe(
        normalizeAllowlist(rspackAllowlist)
      )
    })

    it("both plugins have the same dangerous patterns regex", () => {
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )
      const rspackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/rspack.ts"),
        "utf8"
      )

      // Extract DANGEROUS_PATTERNS from both files
      const webpackPattern = webpackPluginSource.match(
        /DANGEROUS_PATTERNS\s*=\s*\/(.*?)\/i/
      )
      const rspackPattern = rspackPluginSource.match(
        /DANGEROUS_PATTERNS\s*=\s*\/(.*?)\/i/
      )

      expect(webpackPattern).toBeTruthy()
      expect(rspackPattern).toBeTruthy()
      expect(webpackPattern[1]).toBe(rspackPattern[1])
    })
  })

  describe("dangerous pattern warnings", () => {
    it("source includes warning for sensitive variable names", () => {
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )

      expect(webpackPluginSource).toContain("DANGEROUS_PATTERNS")
      expect(webpackPluginSource).toContain("SHAKAPACKER SECURITY WARNING")
      expect(webpackPluginSource).toContain("matches a sensitive pattern")
    })

    it("dangerous patterns include common secret variable patterns", () => {
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )

      const patternMatch = webpackPluginSource.match(
        /DANGEROUS_PATTERNS\s*=\s*\/(.*?)\/i/
      )
      expect(patternMatch).toBeTruthy()

      const patternContent = patternMatch[1]

      // Verify all expected patterns are included
      const expectedPatterns = [
        "SECRET",
        "PASSWORD",
        "KEY",
        "TOKEN",
        "CREDENTIAL",
        "DATABASE_URL",
        "AWS_",
        "PRIVATE",
        "AUTH"
      ]

      expectedPatterns.forEach((pattern) => {
        expect(patternContent).toContain(pattern)
      })
    })
  })

  describe("shakapacker_ENV_VARS edge cases", () => {
    it("source handles whitespace in CSV values", () => {
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )

      // Verify trim() is called on each value
      expect(webpackPluginSource).toMatch(/\.map\(\s*\(?v\)?\s*=>\s*v\.trim\(\)/)
    })

    it("source filters empty values from CSV", () => {
      const webpackPluginSource = require("fs").readFileSync(
        require("path").resolve(__dirname, "../../../package/plugins/webpack.ts"),
        "utf8"
      )

      // Verify filter(Boolean) is called to remove empty strings
      expect(webpackPluginSource).toMatch(/\.filter\(Boolean\)/)
    })
  })
})
