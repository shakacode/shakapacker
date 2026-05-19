const { chdirTestApp, resetEnv } = require("../../helpers")

const rootPath = process.cwd()
chdirTestApp()

const loadRspackDevelopmentConfig = (reactRefreshModule) => {
  jest.resetModules()
  resetEnv()
  process.env.RAILS_ENV = "development"
  process.env.NODE_ENV = "development"
  process.env.WEBPACK_SERVE = "true"
  process.env.SHAKAPACKER_ASSETS_BUNDLER = "rspack"

  jest.doMock("../../../package/utils/helpers", () => {
    const original = jest.requireActual("../../../package/utils/helpers")
    return {
      ...original,
      moduleExists: (moduleName) =>
        moduleName === "@rspack/plugin-react-refresh"
    }
  })
  jest.doMock("@rspack/core", () => ({
    EnvironmentPlugin: function EnvironmentPlugin() {}
  }))
  jest.doMock("rspack-manifest-plugin", () => ({
    RspackManifestPlugin: function RspackManifestPlugin() {}
  }))
  jest.doMock("@rspack/plugin-react-refresh", () => reactRefreshModule, {
    virtual: true
  })

  return require("../../../package/environments/development")
}

describe("Rspack React refresh development config", () => {
  afterEach(() => {
    jest.dontMock("../../../package/utils/helpers")
    jest.dontMock("@rspack/core")
    jest.dontMock("rspack-manifest-plugin")
    jest.dontMock("@rspack/plugin-react-refresh")
  })

  afterAll(() => process.chdir(rootPath))

  test("loads ReactRefreshRspackPlugin from the named export", () => {
    function ReactRefreshRspackPlugin() {}

    const environmentConfig = loadRspackDevelopmentConfig({
      ReactRefreshRspackPlugin
    })

    expect(
      environmentConfig.plugins.some(
        (plugin) => plugin instanceof ReactRefreshRspackPlugin
      )
    ).toBe(true)
  })

  test("keeps compatibility with the direct CommonJS export", () => {
    function ReactRefreshRspackPlugin() {}

    const environmentConfig = loadRspackDevelopmentConfig(
      ReactRefreshRspackPlugin
    )

    expect(
      environmentConfig.plugins.some(
        (plugin) => plugin instanceof ReactRefreshRspackPlugin
      )
    ).toBe(true)
  })

  test("falls back to .default when only a default export is present", () => {
    function ReactRefreshRspackPlugin() {}

    const environmentConfig = loadRspackDevelopmentConfig({
      default: ReactRefreshRspackPlugin
    })

    expect(
      environmentConfig.plugins.some(
        (plugin) => plugin instanceof ReactRefreshRspackPlugin
      )
    ).toBe(true)
  })
})
