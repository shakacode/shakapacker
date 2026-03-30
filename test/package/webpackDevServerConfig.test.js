const { chdirTestApp, resetEnv } = require("../helpers")

const rootPath = process.cwd()
chdirTestApp()

describe("webpackDevServerConfig", () => {
  beforeEach(() => {
    jest.resetModules()
    resetEnv()
    process.env.NODE_ENV = "development"
    process.env.RAILS_ENV = "development"
  })
  afterAll(() => process.chdir(rootPath))

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
