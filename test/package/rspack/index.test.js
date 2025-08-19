const { generateRspackConfig, config, rules } = require("../../../package/rspack")

describe("Rspack integration", () => {

  test("generateRspackConfig exists and is a function", () => {
    expect(typeof generateRspackConfig).toBe("function")
  })

  test("generateRspackConfig returns a configuration object", () => {
    const rspackConfig = generateRspackConfig()
    expect(typeof rspackConfig).toBe("object")
    expect(rspackConfig.mode).toBeDefined()
    expect(rspackConfig.entry).toBeDefined()
    expect(rspackConfig.output).toBeDefined()
  })

  test("uses rspack-specific plugins", () => {
    const rspackConfig = generateRspackConfig()
    const pluginNames = rspackConfig.plugins.map(plugin => plugin.constructor.name)
    
    // Should include rspack environment plugin
    expect(pluginNames).toContain("EnvironmentPlugin")
    
    // Should include webpack assets manifest (compatible with rspack)
    expect(pluginNames).toContain("WebpackAssetsManifest")
  })

  test("includes rspack-specific rules", () => {
    expect(Array.isArray(rules)).toBe(true)
    expect(rules.length).toBeGreaterThan(0)
    
    // Should have JavaScript/TypeScript rule using builtin:swc-loader
    const jsRule = rules.find(rule => 
      rule.test && rule.test.test && rule.test.test("test.js")
    )
    expect(jsRule).toBeDefined()
    expect(jsRule.use[0].loader).toBe("builtin:swc-loader")
  })

  test("shares config with webpack", () => {
    // Should use the same shakapacker.yml config
    expect(config).toBeDefined()
    expect(config.source_path).toBeDefined()
    expect(config.public_output_path).toBeDefined()
  })

  test("supports asset modules", () => {
    const fileRule = rules.find(rule => 
      rule && rule.test && rule.test.test && rule.test.test("image.png")
    )
    expect(fileRule).toBeDefined()
    expect(fileRule.type).toBe("asset/resource")
  })
})