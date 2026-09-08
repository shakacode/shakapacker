// Covers the configuration Shakapacker emits when css-loader is absent and the
// bundler parses CSS itself.

const { chdirTestApp, resetEnv } = require("../../helpers")

const rootPath = process.cwd()
chdirTestApp()

const loadBaseConfig = ({ assetsBundler = "webpack", cssLoader = false }) => {
  jest.resetModules()
  resetEnv()
  process.env.NODE_ENV = "production"
  if (assetsBundler === "rspack") {
    process.env.SHAKAPACKER_ASSETS_BUNDLER = "rspack"
  }

  jest.doMock("../../../package/utils/helpers", () => {
    const original = jest.requireActual("../../../package/utils/helpers")
    return {
      ...original,
      moduleExists: (moduleName) =>
        moduleName === "css-loader" ? cssLoader : true
    }
  })
  jest.doMock("@rspack/core", () => ({
    EnvironmentPlugin: function EnvironmentPlugin() {}
  }))
  jest.doMock("rspack-manifest-plugin", () => ({
    RspackManifestPlugin: function RspackManifestPlugin() {}
  }))

  return require("../../../package/environments/base")
}

describe("base config without css-loader", () => {
  afterAll(() => {
    delete process.env.SHAKAPACKER_ASSETS_BUNDLER
    process.chdir(rootPath)
  })

  test("enables webpack's built-in CSS support explicitly", () => {
    // Required across the whole supported webpack range: `experiments.css` is
    // `false` before 5.109, and from 5.109 the `'auto'` default turns built-in
    // CSS *off* as soon as a rule declares an explicit `css/auto` type - which
    // is exactly what getStyleRule emits. Without this, webpack fails with
    // "No parser registered for css/auto".
    expect(loadBaseConfig({}).experiments).toStrictEqual({ css: true })
  })

  test("names extracted stylesheets the way the css-loader path does", () => {
    const { output } = loadBaseConfig({})

    expect(output.cssFilename).toBe("css/[name]-[contenthash:8].css")
    expect(output.cssChunkFilename).toBe("css/[id]-[contenthash:8].css")
  })

  test("does not set the deprecated experiments.css on Rspack", () => {
    // Rspack v2 deprecated `experiments.css`; the `css/auto` rule type is the
    // documented way to turn on its built-in CSS support.
    expect(
      loadBaseConfig({ assetsBundler: "rspack" }).experiments
    ).toBeUndefined()
  })
})

describe("base config with css-loader", () => {
  afterAll(() => {
    delete process.env.SHAKAPACKER_ASSETS_BUNDLER
    process.chdir(rootPath)
  })

  test("leaves built-in CSS support alone", () => {
    const baseConfig = loadBaseConfig({ cssLoader: true })

    expect(baseConfig.experiments).toBeUndefined()
    expect(baseConfig.output.cssFilename).toBeUndefined()
    expect(baseConfig.output.cssChunkFilename).toBeUndefined()
  })
})
