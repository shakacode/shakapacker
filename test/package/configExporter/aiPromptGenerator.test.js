const {
  AiPromptGenerator,
  FileWriter
} = require("../../../package/configExporter")

describe("AiPromptGenerator", () => {
  let generator

  beforeEach(() => {
    generator = new AiPromptGenerator()
  })

  test("generatePromptFilename returns correct filename", () => {
    const filename = generator.generatePromptFilename()
    expect(filename).toBe("AI-ANALYSIS-PROMPT.md")
  })

  test("generatePrompt includes all sections for webpack", () => {
    const exportedFiles = [
      "webpack-development-client.yml",
      "webpack-development-server.yml",
      "webpack-production-client.yml",
      "webpack-production-server.yml"
    ]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Check for major sections
    expect(prompt).toContain("# AI Configuration Analysis Request")
    expect(prompt).toContain("## Context")
    expect(prompt).toContain("## Configuration Files")
    expect(prompt).toContain("## React on Rails Standard Configuration")
    expect(prompt).toContain("## Analysis Objectives")
    expect(prompt).toContain("### 1. Migration Issues")
    expect(prompt).toContain("### 2. Build Errors & Warnings")
    expect(prompt).toContain("### 3. Client vs Server Optimization")
    expect(prompt).toContain("### 4. Development vs Production Optimization")
    expect(prompt).toContain("### 5. Common Best Practices")
    expect(prompt).toContain("## Providing Additional Context")
    expect(prompt).toContain("## Desired Output Format")

    // Check bundler is mentioned
    expect(prompt).toContain("**Bundler**: webpack")
  })

  test("generatePrompt includes all sections for rspack", () => {
    const exportedFiles = [
      "rspack-development-client.yml",
      "rspack-development-server.yml",
      "rspack-production-client.yml",
      "rspack-production-server.yml"
    ]
    const targetDir = "/path/to/exports"
    const bundler = "rspack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Check bundler is mentioned
    expect(prompt).toContain("**Bundler**: rspack")
  })

  test("generatePrompt lists all configuration files with matching labels", () => {
    const exportedFiles = [
      "webpack-development-client.yml",
      "webpack-development-server.yml",
      "webpack-production-client.yml",
      "webpack-production-server.yml"
    ]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Check that each file is paired with its label and description
    expect(prompt).toContain(
      "- **Development (Client)**: `webpack-development-client.yml` - Client bundle for development mode"
    )
    expect(prompt).toContain(
      "- **Development (Server)**: `webpack-development-server.yml` - Server-side rendering bundle for development mode"
    )
    expect(prompt).toContain(
      "- **Production (Client)**: `webpack-production-client.yml` - Client bundle for production mode"
    )
    expect(prompt).toContain(
      "- **Production (Server)**: `webpack-production-server.yml` - Server-side rendering bundle for production mode"
    )
  })

  test("generatePrompt lists every file produced by real doctor-mode exports", () => {
    // Mirror the filenames the doctor flows actually generate: the
    // no-config-file path (development-hmr build name, "all" config type) and
    // the config-file path with user-defined build names like "dev" and "prod"
    const exportedFiles = [
      FileWriter.generateFilename(
        "webpack",
        "development",
        "client",
        "yaml",
        "development-hmr"
      ),
      FileWriter.generateFilename("webpack", "development", "all", "yaml"),
      FileWriter.generateFilename("webpack", "production", "all", "yaml"),
      FileWriter.generateFilename(
        "webpack",
        "development",
        "client",
        "yaml",
        "dev"
      ),
      FileWriter.generateFilename(
        "webpack",
        "production",
        "server",
        "yaml",
        "prod"
      )
    ]
    expect(exportedFiles).toStrictEqual([
      "webpack-development-hmr-client.yml",
      "webpack-development-all.yml",
      "webpack-production-all.yml",
      "webpack-dev-client.yml",
      "webpack-prod-server.yml"
    ])

    const prompt = generator.generatePrompt(
      exportedFiles,
      "/path/to/exports",
      "webpack"
    )

    for (const file of exportedFiles) {
      expect(prompt).toContain(`\`${file}\``)
    }

    // Spot-check the best-effort labels
    expect(prompt).toContain(
      "- **Development (Client, HMR)**: `webpack-development-hmr-client.yml` - Client bundle with Hot Module Replacement for development mode"
    )
    expect(prompt).toContain(
      "- **Development (All bundles)**: `webpack-development-all.yml` - Combined client and server configuration for development mode"
    )
    expect(prompt).toContain(
      "- **Development (Client)**: `webpack-dev-client.yml` - Client bundle for development mode"
    )
    expect(prompt).toContain(
      "- **Production (Server)**: `webpack-prod-server.yml` - Server-side rendering bundle for production mode"
    )

    // HMR troubleshooting note only appears when an HMR file is present
    expect(prompt).toContain("The HMR config is especially useful")
  })

  test("generatePrompt lists unrecognized filenames without a label", () => {
    const exportedFiles = ["webpack-my-custom-build-extras.yml"]

    const prompt = generator.generatePrompt(
      exportedFiles,
      "/path/to/exports",
      "webpack"
    )

    expect(prompt).toContain("- `webpack-my-custom-build-extras.yml`")
    expect(prompt).not.toContain("The HMR config is especially useful")
  })

  test("generatePrompt notes when no configuration files were exported", () => {
    const prompt = generator.generatePrompt([], "/path/to/exports", "webpack")

    expect(prompt).toContain("No configuration files were exported.")
    expect(prompt).not.toContain(
      "The following configuration files are available for analysis:"
    )
  })

  test("generatePrompt handles partial file lists", () => {
    const exportedFiles = ["webpack-development-client.yml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Should still contain main sections
    expect(prompt).toContain("# AI Configuration Analysis Request")
    expect(prompt).toContain("## Configuration Files")
    expect(prompt).toContain("webpack-development-client.yml")

    // Should not contain files that aren't present
    expect(prompt).not.toContain("webpack-production-server.yml")
  })

  test("generatePrompt includes the export directory", () => {
    const prompt = generator.generatePrompt(
      ["webpack-development-client.yml"],
      "/path/to/exports",
      "webpack"
    )

    expect(prompt).toContain("- **Export Directory**: /path/to/exports")
  })

  test("generatePrompt includes React on Rails context by default", () => {
    const exportedFiles = ["webpack-development-client.yml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    expect(prompt).toContain("## React on Rails Standard Configuration")
    // Phrasing must stay conditional: Shakapacker is also used without React on Rails
    expect(prompt).toContain("If this project uses React on Rails")
    expect(prompt).toContain("config/webpack/webpack.config.js")
    expect(prompt).toContain("commonWebpackConfig.js")
    expect(prompt).toContain("clientWebpackConfig.js")
    expect(prompt).toContain("serverWebpackConfig.js")

    // Check for reference links (monorepo layout under react_on_rails/)
    expect(prompt).toContain("### Reference Configuration Examples")
    expect(prompt).toContain(
      "https://github.com/shakacode/react_on_rails/blob/main/react_on_rails/spec/dummy/config/webpack/commonWebpackConfig.js"
    )
  })

  test("generatePrompt can exclude React on Rails context", () => {
    const exportedFiles = ["webpack-development-client.yml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(
      exportedFiles,
      targetDir,
      bundler,
      false
    )

    expect(prompt).not.toContain("## React on Rails Standard Configuration")
  })

  test("generatePrompt includes analysis objectives", () => {
    const exportedFiles = ["rspack-development-client.yml"]
    const targetDir = "/path/to/exports"
    const bundler = "rspack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Check for optimization recommendations
    expect(prompt).toContain("Code splitting strategy")
    expect(prompt).toContain("Tree shaking effectiveness")
    expect(prompt).toContain("Verify single-chunk output")
    expect(prompt).toContain("Hot Module Replacement (HMR)")
    expect(prompt).toContain("Minification and optimization")
    expect(prompt).toContain("Efficient caching strategies")
  })

  test("generatePrompt includes instructions for providing build errors", () => {
    const exportedFiles = ["webpack-development-client.yml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    expect(prompt).toContain("bin/shakapacker")
    expect(prompt).toContain("bin/shakapacker-dev-server")
    expect(prompt).toContain("Build Error Logs")
  })

  test("generatePrompt includes desired output format", () => {
    const exportedFiles = ["webpack-development-client.yml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    expect(prompt).toContain("Executive Summary")
    expect(prompt).toContain("Critical Issues")
    expect(prompt).toContain("Warnings")
    expect(prompt).toContain("Optimizations")
    expect(prompt).toContain("Configuration Diffs")
  })

  test("generatePrompt includes footer with metadata", () => {
    const exportedFiles = ["webpack-development-client.yml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    expect(prompt).toContain("Generated by Shakapacker Config Exporter")
    expect(prompt).toContain("**Bundler**: webpack")
    expect(prompt).toMatch(/\*\*Date\*\*: \d{4}-\d{2}-\d{2}T/)
  })

  test("generatePrompt uses the same timestamp in header and footer", () => {
    const prompt = generator.generatePrompt(
      ["webpack-development-client.yml"],
      "/path/to/exports",
      "webpack"
    )

    const exportedAt = prompt.match(/\*\*Exported At\*\*: (\S+)/)[1]
    const footerDate = prompt.match(/\*\*Date\*\*: (\S+)/)[1]
    expect(exportedAt).toBe(footerDate)
  })
})
