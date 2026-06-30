const { chdirTestApp, resetEnv } = require("../../helpers")

const rootPath = process.cwd()
chdirTestApp()

const loadRspackDevelopmentConfig = (
  reactRefreshModule = {
    ReactRefreshRspackPlugin: function ReactRefreshRspackPlugin() {}
  },
  webpackServe = "true"
) => {
  jest.resetModules()
  resetEnv()
  process.env.RAILS_ENV = "development"
  process.env.NODE_ENV = "development"
  process.env.SHAKAPACKER_ASSETS_BUNDLER = "rspack"
  if (webpackServe !== null) process.env.WEBPACK_SERVE = webpackServe

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

const hasReactRefreshPluginInstance = (environmentConfig) => {
  const plugins = environmentConfig.plugins || []
  return plugins.some(
    (plugin) =>
      plugin &&
      plugin.constructor &&
      plugin.constructor.name === "ReactRefreshRspackPlugin"
  )
}

const swcReactTransforms = (environmentConfig) =>
  (environmentConfig.module?.rules || [])
    .flatMap((rule) => (Array.isArray(rule.use) ? rule.use : []))
    .filter((loader) => loader.loader === "builtin:swc-loader")
    .map((loader) => loader.options.jsc.transform.react)

describe("Rspack React refresh development config", () => {
  afterEach(() => {
    jest.restoreAllMocks()
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

  test("enables the SWC React refresh transform when the plugin is loaded", () => {
    const environmentConfig = loadRspackDevelopmentConfig()

    expect(swcReactTransforms(environmentConfig)).toStrictEqual(
      expect.arrayContaining([
        expect.objectContaining({ development: true, refresh: true }),
        expect.objectContaining({ development: true, refresh: true })
      ])
    )
  })

  test("skips the legacy direct CommonJS export shape", () => {
    const warn = jest.spyOn(console, "warn").mockImplementation(() => {})
    function ReactRefreshRspackPlugin() {}

    const environmentConfig = loadRspackDevelopmentConfig(
      ReactRefreshRspackPlugin
    )

    expect(warn).toHaveBeenCalledWith(
      "[SHAKAPACKER WARNING] Could not resolve a constructor from @rspack/plugin-react-refresh; React Refresh will be skipped in development."
    )
    expect(hasReactRefreshPluginInstance(environmentConfig)).toBe(false)
  })

  test("skips the legacy default-only export shape", () => {
    const warn = jest.spyOn(console, "warn").mockImplementation(() => {})
    function ReactRefreshRspackPlugin() {}

    const environmentConfig = loadRspackDevelopmentConfig({
      default: ReactRefreshRspackPlugin
    })

    expect(warn).toHaveBeenCalledWith(
      "[SHAKAPACKER WARNING] Could not resolve a constructor from @rspack/plugin-react-refresh; React Refresh will be skipped in development."
    )
    expect(hasReactRefreshPluginInstance(environmentConfig)).toBe(false)
  })

  test("skips the plugin when no known export shape is present", () => {
    const warn = jest.spyOn(console, "warn").mockImplementation(() => {})

    const environmentConfig = loadRspackDevelopmentConfig({
      someOtherProp: {}
    })

    expect(warn).toHaveBeenCalledWith(
      "[SHAKAPACKER WARNING] Could not resolve a constructor from @rspack/plugin-react-refresh; React Refresh will be skipped in development."
    )
    expect(environmentConfig).toBeDefined()
    expect(hasReactRefreshPluginInstance(environmentConfig)).toBe(false)
  })

  test("omits devServer when webpack dev server is not running", () => {
    const environmentConfig = loadRspackDevelopmentConfig(undefined, null)

    expect(environmentConfig.devServer).toBeUndefined()
  })

  test("sets devServer when webpack dev server is running", () => {
    const environmentConfig = loadRspackDevelopmentConfig()

    expect(environmentConfig.devServer).toBeDefined()
    expect(environmentConfig.lazyCompilation).toBe(false)
    expect(environmentConfig.devServer.devMiddleware.writeToDisk).toStrictEqual(
      expect.any(Function)
    )
    const { writeToDisk } = environmentConfig.devServer.devMiddleware
    expect(writeToDisk("/packs/app.hot-update.js")).toBe(false)
    expect(writeToDisk("/packs/app.js")).toBe(true)
  })

  test("sets lazyCompilation false when webpack dev server is not running", () => {
    const environmentConfig = loadRspackDevelopmentConfig(undefined, null)

    expect(environmentConfig.lazyCompilation).toBe(false)
  })
})
