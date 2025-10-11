/* eslint-disable no-template-curly-in-string */
const { writeFileSync, mkdirSync, rmSync, existsSync } = require("fs")
const { resolve, join } = require("path")
const {
  ConfigFileLoader,
  generateSampleConfigFile
} = require("../../package/configExporter")

describe("ConfigFileLoader", () => {
  const testDir = resolve(__dirname, "../tmp/config-file-test")
  let configPath

  beforeEach(() => {
    // Create test directory
    if (!existsSync(testDir)) {
      mkdirSync(testDir, { recursive: true })
    }
    configPath = join(testDir, ".bundler-config.yml")
  })

  afterEach(() => {
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
  })

  describe("validateConfigPath", () => {
    it("should reject path traversal attempts with ..", () => {
      // Use a path that's definitely outside the project
      const maliciousPath = "/etc/passwd"
      expect(() => {
        // eslint-disable-next-line no-new
        new ConfigFileLoader(maliciousPath)
      }).toThrow(/Config file must be within project directory/)
    })

    it("should accept paths within the project directory", () => {
      expect(() => {
        // eslint-disable-next-line no-new
        new ConfigFileLoader(configPath)
      }).not.toThrow()
    })
  })

  describe("exists", () => {
    it("should return false when config file does not exist", () => {
      const loader = new ConfigFileLoader(configPath)
      expect(loader.exists()).toBe(false)
    })

    it("should return true when config file exists", () => {
      writeFileSync(configPath, "default_bundler: webpack\nbuilds: {}")
      const loader = new ConfigFileLoader(configPath)
      expect(loader.exists()).toBe(true)
    })
  })

  describe("load", () => {
    it("should load valid YAML config", () => {
      writeFileSync(
        configPath,
        `
default_bundler: rspack
builds:
  dev:
    description: Development build
    environment:
      NODE_ENV: development
    outputs:
      - client
      - server
`
      )
      const loader = new ConfigFileLoader(configPath)
      const loaded = loader.load()
      expect(loaded.default_bundler).toBe("rspack")
      expect(loaded.builds.dev).toBeDefined()
      expect(loaded.builds.dev.description).toBe("Development build")
    })

    it("should throw error for malformed YAML", () => {
      writeFileSync(configPath, "invalid: yaml: content:\n  - broken")
      const loader = new ConfigFileLoader(configPath)
      expect(() => loader.load()).toThrow(Error)
    })

    it("should throw error if builds key is missing", () => {
      writeFileSync(configPath, "default_bundler: webpack")
      const loader = new ConfigFileLoader(configPath)
      expect(() => loader.load()).toThrow(/must contain a 'builds'/)
    })

    it("should throw error if builds is not an object", () => {
      writeFileSync(configPath, "builds: []")
      const loader = new ConfigFileLoader(configPath)
      expect(() => loader.load()).toThrow(/must contain at least one build/)
    })
  })

  describe("resolveBuild", () => {
    beforeEach(() => {
      writeFileSync(
        configPath,
        `
default_bundler: rspack
builds:
  dev:
    description: Development build
    environment:
      NODE_ENV: development
      RAILS_ENV: development
    outputs:
      - client
      - server
  prod:
    description: Production build
    bundler: webpack
    environment:
      NODE_ENV: production
    outputs:
      - client
`
      )
    })

    it("should throw error for non-existent build", () => {
      const loader = new ConfigFileLoader(configPath)
      expect(() => {
        loader.resolveBuild("nonexistent", {}, "webpack")
      }).toThrow(/Build 'nonexistent' not found/)
    })

    it("should resolve build with environment variables", () => {
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("dev", {}, "webpack")
      expect(resolved.name).toBe("dev")
      expect(resolved.environment.NODE_ENV).toBe("development")
      expect(resolved.environment.RAILS_ENV).toBe("development")
      expect(resolved.outputs).toStrictEqual(["client", "server"])
    })

    it("should use build-specific bundler over default", () => {
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("prod", {}, "rspack")
      expect(resolved.bundler).toBe("webpack")
    })

    it("should use CLI bundler option over everything", () => {
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild(
        "prod",
        { bundler: "rspack" },
        "webpack"
      )
      expect(resolved.bundler).toBe("rspack")
    })
  })

  describe("edge case validation", () => {
    it("should throw error for empty outputs array", () => {
      writeFileSync(
        configPath,
        `
builds:
  bad:
    environment:
      NODE_ENV: development
    outputs: []
`
      )
      const loader = new ConfigFileLoader(configPath)
      expect(() => {
        loader.resolveBuild("bad", {}, "webpack")
      }).toThrow(/empty outputs array/)
    })

    it("should throw error for duplicate outputs", () => {
      writeFileSync(
        configPath,
        `
builds:
  bad:
    environment:
      NODE_ENV: development
    outputs:
      - client
      - client
      - server
`
      )
      const loader = new ConfigFileLoader(configPath)
      expect(() => {
        loader.resolveBuild("bad", {}, "webpack")
      }).toThrow(/duplicate output types/)
    })

    it("should throw error for invalid config file path with path traversal", () => {
      writeFileSync(
        configPath,
        `
builds:
  bad:
    environment:
      NODE_ENV: development
    config: ../../../malicious.js
    outputs:
      - client
`
      )
      const loader = new ConfigFileLoader(configPath)
      expect(() => {
        loader.resolveBuild("bad", {}, "webpack")
      }).toThrow(/Invalid config file path/)
    })
  })

  describe("environment variable expansion", () => {
    beforeEach(() => {
      process.env.TEST_VAR = "test-value"
      process.env.BUNDLER_VAR = "should-not-be-used"
    })

    afterEach(() => {
      delete process.env.TEST_VAR
      delete process.env.BUNDLER_VAR
    })

    it("should expand ${BUNDLER} variable", () => {
      writeFileSync(
        configPath,
        "builds:\n  test:\n    environment:\n      CONFIG_PATH: config/${BUNDLER}/config.js\n    outputs:\n      - client\n"
      )
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("test", {}, "rspack")
      expect(resolved.environment.CONFIG_PATH).toBe("config/rspack/config.js")
    })

    it("should expand ${VAR} from environment", () => {
      writeFileSync(
        configPath,
        "builds:\n  test:\n    environment:\n      CUSTOM: ${TEST_VAR}\n    outputs:\n      - client\n"
      )
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("test", {}, "webpack")
      expect(resolved.environment.CUSTOM).toBe("test-value")
    })

    it("should expand ${VAR:-default} with default value", () => {
      writeFileSync(
        configPath,
        "builds:\n  test:\n    environment:\n      WITH_DEFAULT: ${NONEXISTENT:-fallback-value}\n    outputs:\n      - client\n"
      )
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("test", {}, "webpack")
      expect(resolved.environment.WITH_DEFAULT).toBe("fallback-value")
    })

    it("should use environment value over default in ${VAR:-default}", () => {
      writeFileSync(
        configPath,
        "builds:\n  test:\n    environment:\n      WITH_DEFAULT: ${TEST_VAR:-fallback-value}\n    outputs:\n      - client\n"
      )
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("test", {}, "webpack")
      expect(resolved.environment.WITH_DEFAULT).toBe("test-value")
    })

    it("should reject invalid environment variable names", () => {
      writeFileSync(
        configPath,
        "builds:\n  test:\n    environment:\n      BAD: ${Invalid-Var-Name}\n    outputs:\n      - client\n"
      )
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("test", {}, "webpack")
      // Should not expand invalid var names (contains hyphen)
      expect(resolved.environment.BAD).toBe("${Invalid-Var-Name}")
    })
  })

  describe("bundler_env conversion", () => {
    it("should convert bundler_env to CLI arguments", () => {
      writeFileSync(
        configPath,
        `
builds:
  test:
    environment:
      NODE_ENV: production
    bundler_env:
      target: modern
      instrumented: true
      disabled: false
    outputs:
      - client
`
      )
      const loader = new ConfigFileLoader(configPath)
      const resolved = loader.resolveBuild("test", {}, "webpack")
      expect(resolved.bundlerEnvArgs).toContain("--env")
      expect(resolved.bundlerEnvArgs).toContain("target=modern")
      // Boolean true becomes "--env key=true" (not just "instrumented")
      expect(resolved.bundlerEnvArgs.join(" ")).toContain("instrumented")
      // false values are still included as "disabled=false"
      expect(resolved.bundlerEnvArgs).toContain("disabled=false")
    })
  })
})

describe("generateSampleConfigFile", () => {
  it("should generate valid YAML string", () => {
    const content = generateSampleConfigFile()
    expect(content).toContain("default_bundler:")
    expect(content).toContain("builds:")
    expect(content).toContain("dev-hmr:")
    expect(content).toContain("dev:")
    expect(content).toContain("prod:")
  })

  it("should include documentation comments", () => {
    const content = generateSampleConfigFile()
    expect(content).toContain("# Bundler Build Configurations")
    expect(content).toContain("HMR")
    expect(content).toContain("production")
  })

  it("should escape template literal variables correctly", () => {
    const content = generateSampleConfigFile()
    // Should have ${BUNDLER} not actual 'webpack' or 'rspack'
    expect(content).toContain("${BUNDLER}")
    expect(content).toContain("${RAILS_ENV:-staging}")
  })
})
