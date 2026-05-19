describe("rspack/index side effects", () => {
  const mockConfigForRspack = () => {
    jest.doMock("../../../package/config", () => {
      const actual = jest.requireActual("../../../package/config")
      return {
        ...actual,
        assets_bundler: "rspack"
      }
    })
  }

  // Returns a `requireOrError` mock that yields working fakes for the modules
  // loaded by the rules chain (`getStyleRule` reaches `@rspack/core` at
  // require-time), so the rspack index can be loaded without throwing while
  // we observe which modules were requested.
  const mockRequireOrError = () => {
    const requireOrError = jest.fn((moduleName) => {
      if (moduleName === "@rspack/core") {
        const CssExtractRspackPlugin = jest.fn()
        CssExtractRspackPlugin.loader = "css-extract-rspack-loader"
        return {
          CssExtractRspackPlugin,
          DefinePlugin: jest.fn(),
          EnvironmentPlugin: jest.fn(),
          ProvidePlugin: jest.fn(),
          HotModuleReplacementPlugin: jest.fn(),
          ProgressPlugin: jest.fn(),
          SubresourceIntegrityPlugin: jest.fn(),
          SwcJsMinimizerRspackPlugin: jest.fn(),
          LightningCssMinimizerRspackPlugin: jest.fn()
        }
      }
      if (moduleName === "rspack-manifest-plugin") {
        return { RspackManifestPlugin: jest.fn() }
      }
      return {}
    })

    jest.doMock("../../../package/utils/requireOrError", () => ({
      requireOrError
    }))

    return requireOrError
  }

  test("does not eagerly load rspack-manifest-plugin when only requiring the rspack index", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()

      require("../../../package/rspack/index")

      const requestedModules = requireOrError.mock.calls.map((call) => call[0])
      expect(requestedModules).not.toContain("rspack-manifest-plugin")
    })
  })

  test("defines baseConfig as a configurable lazy export", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")

      expect(
        Object.getOwnPropertyDescriptor(rspackIndex, "baseConfig")
      ).toStrictEqual(
        expect.objectContaining({
          configurable: true,
          enumerable: true,
          get: expect.any(Function)
        })
      )
    })
  })

  test("accessing baseConfig triggers the rspack-manifest-plugin load", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")
      const beforeAccess = requireOrError.mock.calls.map((call) => call[0])
      expect(beforeAccess).not.toContain("rspack-manifest-plugin")

      rspackIndex.baseConfig // eslint-disable-line no-unused-expressions

      const afterAccess = requireOrError.mock.calls.map((call) => call[0])
      expect(afterAccess).toContain("rspack-manifest-plugin")
    })
  })
})
