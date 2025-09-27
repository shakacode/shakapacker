jest.mock("../../../package/utils/helpers", () => ({
  canProcess: () => false,
  moduleExists: () => true
}))

jest.mock("../../../package/utils/requireOrError", () => ({
  requireOrError: () => require("mini-css-extract-plugin")
}))

jest.mock("../../../package/config", () => ({
  assets_bundler: "webpack"
}))

jest.mock("../../../package/utils/inliningCss", () => false)

jest.mock("mini-css-extract-plugin", () => ({
  loader: "mini-css-extract-plugin-loader"
}))

const { getStyleRule } = require("../../../package/utils/getStyleRule")

describe("getStyleRule", () => {
  describe("when css-loader exists", () => {
    test("returns a rule with css-loader configuration", () => {
      const rule = getStyleRule(/\.css$/i)
      
      expect(rule).toBeDefined()
      expect(rule.test).toEqual(/\.css$/i)
      expect(rule.use).toBeInstanceOf(Array)
    })

    test("configures css-loader with namedExport: true", () => {
      const rule = getStyleRule(/\.css$/i)
      const cssLoader = rule.use.find(use => 
        use && typeof use === 'object' && use.loader && 
        typeof use.loader === 'string' && use.loader.includes("css-loader")
      )
      
      expect(cssLoader).toBeDefined()
      expect(cssLoader.options.modules.namedExport).toBe(true)
    })

    test("configures css-loader with exportLocalsConvention: camelCase", () => {
      const rule = getStyleRule(/\.css$/i)
      const cssLoader = rule.use.find(use => 
        use && typeof use === 'object' && use.loader && 
        typeof use.loader === 'string' && use.loader.includes("css-loader")
      )
      
      expect(cssLoader.options.modules.exportLocalsConvention).toBe("camelCase")
    })

    test("configures css-loader with auto: true for CSS modules", () => {
      const rule = getStyleRule(/\.css$/i)
      const cssLoader = rule.use.find(use => 
        use && typeof use === 'object' && use.loader && 
        typeof use.loader === 'string' && use.loader.includes("css-loader")
      )
      
      expect(cssLoader.options.modules.auto).toBe(true)
    })

    test("includes sourceMap configuration", () => {
      const rule = getStyleRule(/\.css$/i)
      const cssLoader = rule.use.find(use => 
        use && typeof use === 'object' && use.loader && 
        typeof use.loader === 'string' && use.loader.includes("css-loader")
      )
      
      expect(cssLoader.options.sourceMap).toBe(true)
    })

    test("sets importLoaders to 2", () => {
      const rule = getStyleRule(/\.css$/i)
      const cssLoader = rule.use.find(use => 
        use && typeof use === 'object' && use.loader && 
        typeof use.loader === 'string' && use.loader.includes("css-loader")
      )
      
      expect(cssLoader.options.importLoaders).toBe(2)
    })

    test("includes preprocessors in the use array", () => {
      const preprocessor = { loader: "sass-loader", options: {} }
      const rule = getStyleRule(/\.scss$/i, [preprocessor])
      
      expect(rule.use).toContain(preprocessor)
    })
  })
})