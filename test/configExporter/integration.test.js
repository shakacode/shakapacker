const {
  writeFileSync,
  mkdirSync,
  rmSync,
  existsSync,
  readdirSync
} = require("fs")
const { resolve, join } = require("path")
const { execSync } = require("child_process")

describe("Config Exporter Integration Tests", () => {
  const testDir = resolve(__dirname, "../tmp/integration-test")
  const configPath = join(testDir, ".bundler-config.yml")
  const outputDir = join(testDir, "output")
  const binPath = resolve(__dirname, "../../bin/export-bundler-config")

  beforeEach(() => {
    // Create test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
    mkdirSync(testDir, { recursive: true })

    // Create minimal package.json
    writeFileSync(
      join(testDir, "package.json"),
      JSON.stringify({ name: "test-app", private: true })
    )

    // Create minimal shakapacker.yml
    writeFileSync(
      join(testDir, "shakapacker.yml"),
      `default: &default
  source_path: app/javascript
  source_entry_path: /
  public_root_path: public
  public_output_path: packs

development:
  <<: *default
  compile: true

production:
  <<: *default
  compile: true
`
    )

    // Create minimal webpack config that doesn't require shakapacker
    mkdirSync(join(testDir, "config", "webpack"), { recursive: true })
    writeFileSync(
      join(testDir, "config", "webpack", "webpack.config.js"),
      `module.exports = {
  mode: process.env.NODE_ENV || 'development',
  entry: './app/javascript/application.js',
  output: {
    path: require('path').resolve(__dirname, '../../public/packs'),
    filename: '[name].js'
  }
}\n`
    )

    // Create minimal entry file
    mkdirSync(join(testDir, "app", "javascript"), { recursive: true })
    writeFileSync(
      join(testDir, "app", "javascript", "application.js"),
      "// Test entry file\nconsole.log('test');\n"
    )
  })

  afterEach(() => {
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true })
    }
  })

  describe("--all-builds with environment variable isolation", () => {
    it("should isolate environment variables between builds", () => {
      // Create config with builds that have different env vars
      const configContent = `
default_bundler: webpack

builds:
  dev-hmr:
    description: Development with HMR
    environment:
      NODE_ENV: development
      RAILS_ENV: development
      WEBPACK_SERVE: "true"
    outputs:
      - client

  dev:
    description: Development without HMR
    environment:
      NODE_ENV: development
      RAILS_ENV: development
    outputs:
      - client

  prod:
    description: Production
    environment:
      NODE_ENV: production
      RAILS_ENV: production
    outputs:
      - client
`
      writeFileSync(configPath, configContent)

      // Run --all-builds command
      const result = execSync(
        `cd "${testDir}" && node "${binPath}" --all-builds --save-dir="${outputDir}"`,
        { encoding: "utf8" }
      )

      // Verify output
      expect(result).toContain("Exporting 3 builds")
      expect(result).toContain("dev-hmr")
      expect(result).toContain("dev")
      expect(result).toContain("prod")

      // Verify files were created
      expect(existsSync(outputDir)).toBe(true)
      const files = readdirSync(outputDir)

      // Should have 3 files (one per build)
      expect(files).toHaveLength(3)
      expect(files).toContain("webpack-dev-hmr-client.yaml")
      expect(files).toContain("webpack-dev-client.yaml")
      expect(files).toContain("webpack-prod-client.yaml")

      // Verify files have different content (proving environment isolation)
      const devHmrContent = require("fs").readFileSync(
        join(outputDir, "webpack-dev-hmr-client.yaml"),
        "utf8"
      )
      const devContent = require("fs").readFileSync(
        join(outputDir, "webpack-dev-client.yaml"),
        "utf8"
      )
      const prodContent = require("fs").readFileSync(
        join(outputDir, "webpack-prod-client.yaml"),
        "utf8"
      )

      // All three files should be different (proving isolation)
      expect(devHmrContent).not.toBe(devContent)
      expect(devContent).not.toBe(prodContent)
      expect(devHmrContent).not.toBe(prodContent)

      // Verify environment-specific values
      expect(devContent).toContain("mode: development")
      expect(prodContent).toContain("mode: production")
    })
  })

  describe("--doctor mode with shakapacker_doctor_default_builds_here", () => {
    it("should use config file builds when flag is set", () => {
      // Create config with custom builds and the flag
      const configContent = `
shakapacker_doctor_default_builds_here: true
default_bundler: webpack

builds:
  custom-dev:
    description: Custom development
    environment:
      NODE_ENV: development
      RAILS_ENV: development
    outputs:
      - client

  custom-prod:
    description: Custom production
    environment:
      NODE_ENV: production
      RAILS_ENV: production
    outputs:
      - client
`
      writeFileSync(configPath, configContent)

      // Run --doctor command
      const result = execSync(
        `cd "${testDir}" && node "${binPath}" --doctor --save-dir="${outputDir}"`,
        { encoding: "utf8" }
      )

      // Verify it used config builds, not hardcoded ones
      expect(result).toContain(
        "Using builds from config file (shakapacker_doctor_default_builds_here: true)"
      )
      expect(result).toContain("custom-dev")
      expect(result).toContain("custom-prod")

      // Verify files
      expect(existsSync(outputDir)).toBe(true)
      const files = readdirSync(outputDir)
      expect(files).toContain("webpack-custom-dev-client.yaml")
      expect(files).toContain("webpack-custom-prod-client.yaml")
    })

    it("should use hardcoded builds when flag is not set", () => {
      // Create config WITHOUT the flag
      const configContent = `
default_bundler: webpack

builds:
  custom-dev:
    description: Custom development
    environment:
      NODE_ENV: development
    outputs:
      - client
`
      writeFileSync(configPath, configContent)

      // Run --doctor command
      const result = execSync(
        `cd "${testDir}" && node "${binPath}" --doctor --save-dir="${outputDir}"`,
        { encoding: "utf8" }
      )

      // Verify it used hardcoded builds (development-hmr, development, production)
      expect(result).toContain("development-hmr")
      expect(result).toContain("development")
      expect(result).toContain("production")
      expect(result).not.toContain("custom-dev")
    })
  })

  describe("hMR config generation", () => {
    it("should generate HMR client config with correct metadata", () => {
      const configContent = `
default_bundler: webpack

builds:
  dev-hmr:
    description: Development with HMR
    environment:
      NODE_ENV: development
      RAILS_ENV: development
      WEBPACK_SERVE: "true"
    outputs:
      - client
`
      writeFileSync(configPath, configContent)

      // Run command
      execSync(
        `cd "${testDir}" && node "${binPath}" --build=dev-hmr --save-dir="${outputDir}"`,
        { encoding: "utf8" }
      )

      // Verify HMR file was created with correct naming
      expect(existsSync(outputDir)).toBe(true)
      const files = readdirSync(outputDir)

      // Should create file with -hmr suffix or similar indicator
      expect(files).toHaveLength(1)
      const filename = files[0]

      // Read content and verify it's a valid webpack config
      const content = require("fs").readFileSync(
        join(outputDir, filename),
        "utf8"
      )
      // Verify it contains webpack config content
      expect(content).toContain("mode: development")
      expect(content).toContain("entry:")
      expect(content).toContain("output:")
    })
  })
})
