describe("Dual bundler support", () => {
  test("can import webpack configuration explicitly", () => {
    const webpack = require("../../package/webpack")
    expect(typeof webpack.generateWebpackConfig).toBe("function")
    expect(webpack.generateWebpackConfig).toBeDefined()
  })

  test("can import rspack configuration explicitly", () => {
    const rspack = require("../../package/rspack")
    expect(typeof rspack.generateRspackConfig).toBe("function")
    expect(rspack.generateRspackConfig).toBeDefined()
  })

  test("legacy import still works (backwards compatibility)", () => {
    const legacy = require("../../package/index")
    expect(typeof legacy.generateWebpackConfig).toBe("function")
    expect(legacy.generateWebpackConfig).toBeDefined()
  })

  test("webpack and rspack use shared configuration", () => {
    const webpack = require("../../package/webpack")
    const rspack = require("../../package/rspack")

    expect(webpack.config.source_path).toBe(rspack.config.source_path)
    expect(webpack.config.public_output_path).toBe(
      rspack.config.public_output_path
    )
    expect(webpack.config.cache_path).toBe(rspack.config.cache_path)
  })

  test("webpack and rspack generate different configurations", () => {
    const webpack = require("../../package/webpack")
    const rspack = require("../../package/rspack")

    const webpackConfig = webpack.generateWebpackConfig()
    const rspackConfig = rspack.generateRspackConfig()

    // Both should have basic webpack structure
    expect(webpackConfig.mode).toBeDefined()
    expect(rspackConfig.mode).toBeDefined()

    // But should have different plugin sets
    const webpackPlugins = webpackConfig.plugins.map((p) => p.constructor.name)
    const rspackPlugins = rspackConfig.plugins.map((p) => p.constructor.name)

    expect(webpackPlugins).toContain("WebpackAssetsManifest")
    expect(rspackPlugins).toContain("WebpackManifestPlugin") // rspack manifest plugin
  })

  test("conditional require works for missing dependencies", () => {
    const {
      conditionalRequire
    } = require("../../package/utils/conditionalRequire")

    // Should work with existing module
    expect(() => conditionalRequire("fs")).not.toThrow()

    // Should fail gracefully with missing module
    expect(() => conditionalRequire("non-existent-module")).toThrow(
      "non-existent-module is required but not installed"
    )

    // Should use fallback when provided
    const fallback = conditionalRequire("non-existent-module", "fallback")
    expect(fallback).toBe("fallback")
  })

  test("both bundlers support the same rule types", () => {
    const webpack = require("../../package/webpack")
    const rspack = require("../../package/rspack")

    expect(Array.isArray(webpack.rules)).toBe(true)
    expect(Array.isArray(rspack.rules)).toBe(true)

    // Both should support JavaScript files
    const webpackJsRule = webpack.rules.find((rule) => {
      // eslint-disable-next-line jest/no-conditional-in-test
      if (!rule.test || !rule.test.test) return false
      return rule.test.test("test.js")
    })
    const rspackJsRule = rspack.rules.find((rule) => {
      // eslint-disable-next-line jest/no-conditional-in-test
      if (!rule.test || !rule.test.test) return false
      return rule.test.test("test.js")
    })

    expect(webpackJsRule).toBeDefined()
    expect(rspackJsRule).toBeDefined()
  })
})
