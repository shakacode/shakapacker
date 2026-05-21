const { chdirTestApp, resetEnv } = require("../helpers")

const rootPath = process.cwd()
chdirTestApp()

describe("webpackDevServerConfig", () => {
  beforeEach(() => {
    jest.resetModules()
    jest.restoreAllMocks()
    jest.dontMock("../../package/dev_server")
    jest.dontMock("../../package/config")
    resetEnv()
    process.env.NODE_ENV = "development"
    process.env.RAILS_ENV = "development"
  })
  afterAll(() => process.chdir(rootPath))

  test("warns and ignores removed middleware hooks", () => {
    const warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {})

    jest.isolateModules(() => {
      jest.doMock("../../package/dev_server", () => ({
        hmr: true,
        host: "127.0.0.1",
        on_before_setup_middleware: () => {},
        on_after_setup_middleware: () => {}
      }))
      jest.doMock("../../package/config", () => ({
        outputPath: "/tmp/packs",
        publicPath: "/packs/"
      }))

      const createDevServerConfig = require("../../package/webpackDevServerConfig")
      const config = createDevServerConfig()

      expect(config.host).toBe("127.0.0.1")
      expect(config.onBeforeSetupMiddleware).toBeUndefined()
      expect(config.onAfterSetupMiddleware).toBeUndefined()
    })

    expect(warnSpy).toHaveBeenCalledTimes(1)
    expect(warnSpy.mock.calls[0][0]).toContain("on_before_setup_middleware")
    expect(warnSpy.mock.calls[0][0]).toContain("on_after_setup_middleware")
    expect(warnSpy.mock.calls[0][0]).toContain("setup_middlewares")
  })

  test("does not warn when removed middleware hooks are absent", () => {
    const warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {})

    jest.isolateModules(() => {
      jest.doMock("../../package/dev_server", () => ({
        hmr: false,
        host: "localhost"
      }))
      jest.doMock("../../package/config", () => ({
        outputPath: "/tmp/packs",
        publicPath: "/packs/"
      }))

      const createDevServerConfig = require("../../package/webpackDevServerConfig")
      createDevServerConfig()
    })

    expect(warnSpy).not.toHaveBeenCalled()
  })

  test("defaults static to false", () => {
    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.static).toBe(false)
  })

  test("passes through static: false from YAML config", () => {
    const devServer = require("../../package/dev_server")
    devServer.static = false

    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.static).toBe(false)
  })

  test("passes through static: true from YAML config", () => {
    const devServer = require("../../package/dev_server")
    devServer.static = true

    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.static).toBe(true)
  })

  test("passes through static string path from YAML config", () => {
    const devServer = require("../../package/dev_server")
    devServer.static = "/custom/static"

    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.static).toBe("/custom/static")
  })

  test("passes through static object from YAML config", () => {
    const devServer = require("../../package/dev_server")
    devServer.static = { directory: "/custom/path", watch: false }

    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.static).toStrictEqual({
      directory: "/custom/path",
      watch: false
    })
  })

  test("passes through static array from YAML config", () => {
    const devServer = require("../../package/dev_server")
    devServer.static = ["/path1", "/path2"]

    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.static).toStrictEqual(["/path1", "/path2"])
  })

  test("sets devMiddleware.publicPath to URL path", () => {
    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.devMiddleware.publicPath).toBe("/packs/")
  })

  test("maps hmr to hot", () => {
    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.hot).toBe(true)
    expect(config.hmr).toBeUndefined()
  })

  test("defaults liveReload to inverse of hmr", () => {
    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    // Test app has hmr: true, so liveReload should default to false
    expect(config.liveReload).toBe(false)
  })

  test("maps snake_case YAML keys to camelCase webpack-dev-server keys", () => {
    const devServer = require("../../package/dev_server")
    devServer.allowed_hosts = "auto"

    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.allowedHosts).toBe("auto")
    expect(config.allowed_hosts).toBeUndefined()
  })

  test("passes through client config", () => {
    const devServer = require("../../package/dev_server")
    devServer.client = { overlay: true }

    const createDevServerConfig = require("../../package/webpackDevServerConfig")
    const config = createDevServerConfig()

    expect(config.client).toStrictEqual({ overlay: true })
  })
})
