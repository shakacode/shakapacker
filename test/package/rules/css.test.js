jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  return {
    ...original,
    moduleExists: () => true,
    canProcess: () => false
  }
})

jest.mock("../../../package/utils/requireOrError", () => ({
  requireOrError: () => require("mini-css-extract-plugin")
}))

jest.mock("../../../package/utils/inliningCss", () => false)

jest.mock("../../../package/config", () => ({
  assets_bundler: "webpack"
}))

jest.mock("mini-css-extract-plugin", () => ({
  loader: "mini-css-extract-plugin-loader"
}))

const css = require("../../../package/rules/css")

describe("CSS rule", () => {
  test("rule structure is correct", () => {
    expect(css).toBeDefined()
    expect(css.test).toEqual(/\.(css)$/i)
    expect(css.use).toBeInstanceOf(Array)
  })

  test("contains css-loader with modules configuration", () => {
    const cssLoaderEntry = css.use.find(entry => 
      entry && typeof entry === 'object' && entry.loader && 
      typeof entry.loader === 'string' && entry.loader.includes("css-loader")
    )
    
    expect(cssLoaderEntry).toBeDefined()
    expect(cssLoaderEntry.options).toBeDefined()
    expect(cssLoaderEntry.options.modules).toBeDefined()
  })

  test("has namedExport enabled for CSS modules (v9 default)", () => {
    const cssLoaderEntry = css.use.find(entry => 
      entry && typeof entry === 'object' && entry.loader && 
      typeof entry.loader === 'string' && entry.loader.includes("css-loader")
    )
    
    expect(cssLoaderEntry.options.modules.namedExport).toBe(true)
  })

  test("uses camelCase export convention for CSS modules (v9 default)", () => {
    const cssLoaderEntry = css.use.find(entry => 
      entry && typeof entry === 'object' && entry.loader && 
      typeof entry.loader === 'string' && entry.loader.includes("css-loader")
    )
    
    expect(cssLoaderEntry.options.modules.exportLocalsConvention).toBe("camelCase")
  })

  test("has auto enabled for CSS modules", () => {
    const cssLoaderEntry = css.use.find(entry => 
      entry && typeof entry === 'object' && entry.loader && 
      typeof entry.loader === 'string' && entry.loader.includes("css-loader")
    )
    
    expect(cssLoaderEntry.options.modules.auto).toBe(true)
  })

  test("has sourceMap enabled", () => {
    const cssLoaderEntry = css.use.find(entry => 
      entry && typeof entry === 'object' && entry.loader && 
      typeof entry.loader === 'string' && entry.loader.includes("css-loader")
    )
    
    expect(cssLoaderEntry.options.sourceMap).toBe(true)
  })

  test("has importLoaders set to 2", () => {
    const cssLoaderEntry = css.use.find(entry => 
      entry && typeof entry === 'object' && entry.loader && 
      typeof entry.loader === 'string' && entry.loader.includes("css-loader")
    )
    
    expect(cssLoaderEntry.options.importLoaders).toBe(2)
  })
})