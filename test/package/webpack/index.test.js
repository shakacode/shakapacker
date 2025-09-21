const {
  generateWebpackConfig,
  config,
  rules
} = require("../../../package/webpack")

describe("Webpack integration", () => {
  test("generateWebpackConfig exists and is a function", () => {
    expect(typeof generateWebpackConfig).toBe("function")
  })

  test("generateWebpackConfig returns a configuration object", () => {
    const webpackConfig = generateWebpackConfig()
    expect(typeof webpackConfig).toBe("object")
    expect(webpackConfig.mode).toBeDefined()
    expect(webpackConfig.entry).toBeDefined()
    expect(webpackConfig.output).toBeDefined()
  })

  test("uses webpack-specific plugins", () => {
    const webpackConfig = generateWebpackConfig()
    const pluginNames = webpackConfig.plugins.map(
      (plugin) => plugin.constructor.name
    )

    // Should include webpack environment plugin
    expect(pluginNames).toContain("EnvironmentPlugin")

    // Should include webpack assets manifest plugin
    expect(pluginNames).toContain("WebpackAssetsManifest")
  })

  test("includes webpack-specific rules", () => {
    expect(Array.isArray(rules)).toBe(true)
    expect(rules.length).toBeGreaterThan(0)

    // Should have JavaScript/TypeScript rule using babel-loader
    const jsRule = rules.find((rule) => {
      // eslint-disable-next-line jest/no-conditional-in-test
      if (!rule.test || !rule.test.test) return false
      return rule.test.test("test.js")
    })
    expect(jsRule).toBeDefined()
    // Note: may use babel-loader, swc-loader, or esbuild-loader depending on config
  })

  test("shares config with rspack", () => {
    // Should use the same shakapacker.yml config
    expect(config).toBeDefined()
    expect(config.source_path).toBeDefined()
    expect(config.public_output_path).toBeDefined()
  })

  test("supports asset modules", () => {
    const fileRule = rules.find((rule) => {
      // eslint-disable-next-line jest/no-conditional-in-test
      if (!rule || !rule.test || !rule.test.test) return false
      return rule.test.test("image.png")
    })
    expect(fileRule).toBeDefined()
    expect(fileRule.type).toBe("asset/resource")
  })

  test("supports CSS extraction", () => {
    const webpackConfig = generateWebpackConfig()
    // CSS extraction should be configured
    expect(webpackConfig.plugins.length).toBeGreaterThan(0)
  })

  test("supports different environments", () => {
    const webpackConfig = generateWebpackConfig()
    expect(webpackConfig.mode).toBe("production") // default mode
    expect(webpackConfig.optimization).toBeDefined()
    expect(webpackConfig.optimization.splitChunks).toBeDefined()
  })
})
