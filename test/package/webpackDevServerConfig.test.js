describe("webpackDevServerConfig", () => {
  beforeEach(() => {
    jest.resetModules()
    jest.restoreAllMocks()
  })

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
})
