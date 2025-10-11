const { AiPromptGenerator } = require("../../../package/configExporter")

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
      "webpack-development-client.yaml",
      "webpack-development-server.yaml",
      "webpack-production-client.yaml",
      "webpack-production-server.yaml"
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
      "rspack-development-client.yaml",
      "rspack-development-server.yaml",
      "rspack-production-client.yaml",
      "rspack-production-server.yaml"
    ]
    const targetDir = "/path/to/exports"
    const bundler = "rspack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Check bundler is mentioned
    expect(prompt).toContain("**Bundler**: rspack")
  })

  test("generatePrompt lists all configuration files", () => {
    const exportedFiles = [
      "webpack-development-client.yaml",
      "webpack-development-server.yaml",
      "webpack-production-client.yaml",
      "webpack-production-server.yaml"
    ]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Check that all files are mentioned
    expect(prompt).toContain("webpack-development-client.yaml")
    expect(prompt).toContain("webpack-development-server.yaml")
    expect(prompt).toContain("webpack-production-client.yaml")
    expect(prompt).toContain("webpack-production-server.yaml")

    // Check file descriptions
    expect(prompt).toContain("Client bundle for development mode")
    expect(prompt).toContain(
      "Server-side rendering bundle for development mode"
    )
    expect(prompt).toContain("Client bundle for production mode")
    expect(prompt).toContain("Server-side rendering bundle for production mode")
  })

  test("generatePrompt handles partial file lists", () => {
    const exportedFiles = ["webpack-development-client.yaml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    // Should still contain main sections
    expect(prompt).toContain("# AI Configuration Analysis Request")
    expect(prompt).toContain("## Configuration Files")
    expect(prompt).toContain("webpack-development-client.yaml")

    // Should not contain files that aren't present
    expect(prompt).not.toContain("webpack-production-server.yaml")
  })

  test("generatePrompt includes React on Rails context by default", () => {
    const exportedFiles = ["webpack-development-client.yaml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    expect(prompt).toContain("## React on Rails Standard Configuration")
    expect(prompt).toContain("config/webpack/webpack.config.js")
    expect(prompt).toContain("commonWebpackConfig.js")
    expect(prompt).toContain("clientWebpackConfig.js")
    expect(prompt).toContain("serverWebpackConfig.js")
  })

  test("generatePrompt can exclude React on Rails context", () => {
    const exportedFiles = ["webpack-development-client.yaml"]
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
    const exportedFiles = ["rspack-development-client.yaml"]
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
    const exportedFiles = ["webpack-development-client.yaml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    expect(prompt).toContain("bin/shakapacker")
    expect(prompt).toContain("bin/shakapacker-dev-server")
    expect(prompt).toContain("Build Error Logs")
  })

  test("generatePrompt includes desired output format", () => {
    const exportedFiles = ["webpack-development-client.yaml"]
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
    const exportedFiles = ["webpack-development-client.yaml"]
    const targetDir = "/path/to/exports"
    const bundler = "webpack"

    const prompt = generator.generatePrompt(exportedFiles, targetDir, bundler)

    expect(prompt).toContain("Generated by Shakapacker Config Exporter")
    expect(prompt).toContain("**Bundler**: webpack")
    expect(prompt).toMatch(/\*\*Date\*\*: \d{4}-\d{2}-\d{2}T/)
  })
})
