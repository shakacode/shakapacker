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

  // Returns a `requireOrError` mock that yields working fakes for modules
  // loaded when lazy rspack exports are accessed, while still letting us
  // observe which modules were requested during the initial index require.
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

  // jest.doMock registrations are global and persist across jest.isolateModules
  // boundaries, so clear them after every test to keep these specs independent
  // of execution order (e.g. under --randomize).
  afterEach(() => {
    jest.dontMock("../../../package/config")
    jest.dontMock("../../../package/utils/requireOrError")
    jest.dontMock("../../../package/utils/validateDependencies")
    jest.dontMock("../../../package/env")
  })

  const mockValidateDependencies = () => {
    jest.doMock("../../../package/utils/validateDependencies", () => ({
      validateRspackDependencies: jest.fn()
    }))
  }

  test("does not eagerly load rspack-manifest-plugin when only requiring the rspack index", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()

      require("../../../package/rspack/index")

      // Requiring the index must not pull in ANY bundler module. Asserting the
      // full request list is empty (rather than spot-checking specific names)
      // gives the test teeth: a newly-added eager dependency would surface here
      // even though the requireOrError mock returns an empty object for unknown
      // modules and would otherwise mask it.
      const requestedModules = requireOrError.mock.calls.map((call) => call[0])
      expect(requestedModules).toStrictEqual([])
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

  test("defines rules as a configurable lazy export", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")

      expect(
        Object.getOwnPropertyDescriptor(rspackIndex, "rules")
      ).toStrictEqual(
        expect.objectContaining({
          configurable: true,
          enumerable: true,
          get: expect.any(Function)
        })
      )
    })
  })

  test("assigning to baseConfig overrides the lazy value without loading rspack-manifest-plugin", () => {
    // If the setter override did not write to the same cache the getter reads,
    // accessing baseConfig back would load the real base config and resolve
    // rspack-manifest-plugin. Asserting it is never requested proves the
    // assignment short-circuits the lazy loader.
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")
      const stub = { mode: "none", entry: {} }

      rspackIndex.baseConfig = stub

      expect(rspackIndex.baseConfig).toBe(stub)
      const requested = requireOrError.mock.calls.map((call) => call[0])
      expect(requested).not.toContain("rspack-manifest-plugin")
    })
  })

  test("assigning undefined to baseConfig caches it without loading", () => {
    // The setter overrides the cache with whatever is assigned, so even an
    // `undefined` assignment short-circuits the lazy loader: rspack-manifest-plugin
    // is never resolved.
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")

      rspackIndex.baseConfig = undefined

      expect(rspackIndex.baseConfig).toBeUndefined()

      const requested = requireOrError.mock.calls.map((call) => call[0])
      expect(requested).not.toContain("rspack-manifest-plugin")
    })
  })

  test("assigning to rules overrides the lazy value", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")
      const stub = [{ test: /\.stub$/, use: [] }]

      rspackIndex.rules = stub

      expect(rspackIndex.rules).toBe(stub)
    })
  })

  test("assigning undefined to rules caches it without loading", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")

      rspackIndex.rules = undefined

      expect(rspackIndex.rules).toBeUndefined()
    })
  })

  test("baseConfig can be overridden via Object.defineProperty", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")
      const stub = { mode: "none", entry: {} }

      Object.defineProperty(rspackIndex, "baseConfig", {
        value: stub,
        writable: true,
        configurable: true
      })

      expect(rspackIndex.baseConfig).toBe(stub)
    })
  })

  test("rules can be overridden via Object.defineProperty", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")
      const stub = [{ test: /\.stub$/, use: [] }]

      Object.defineProperty(rspackIndex, "rules", {
        value: stub,
        writable: true,
        configurable: true
      })

      expect(rspackIndex.rules).toBe(stub)
    })
  })

  test("accessing rules does not trigger the rspack-manifest-plugin load", () => {
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")
      expect(rspackIndex.rules).toBeDefined()

      const afterAccess = requireOrError.mock.calls.map((call) => call[0])
      expect(afterAccess).not.toContain("rspack-manifest-plugin")
    })
  })

  test("memoizes baseConfig across repeated accesses without re-resolving optional deps", () => {
    // Mirrors the webpack memoization spec: the lazy cache must return the
    // same object on repeated access and resolve rspack-manifest-plugin only
    // once. Spying on requireOrError gives the assertion teeth the Node require
    // cache alone would not — a re-running getter would request the plugin again.
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()

      const rspackIndex = require("../../../package/rspack/index")

      const first = rspackIndex.baseConfig
      const second = rspackIndex.baseConfig

      expect(second).toBe(first)
      const manifestLoads = requireOrError.mock.calls.filter(
        (call) => call[0] === "rspack-manifest-plugin"
      )
      expect(manifestLoads).toHaveLength(1)
    })
  })

  test("a baseConfig override flows into generateRspackConfig in the no-environment-file fallback", () => {
    // Exercises the `: lazyBaseConfig.get()` branch of generateRspackConfig
    // (package/rspack/index.ts), only reached when no environments/<env>.js
    // file exists. Pointing nodeEnv at a missing env forces that branch, and a
    // prior `baseConfig` override must flow through to the generated config —
    // without resolving the optional rspack-manifest-plugin.
    jest.isolateModules(() => {
      mockConfigForRspack()
      const requireOrError = mockRequireOrError()
      mockValidateDependencies()
      jest.doMock("../../../package/env", () => ({
        ...jest.requireActual("../../../package/env"),
        nodeEnv: "no-such-env"
      }))

      const rspackIndex = require("../../../package/rspack/index")
      const stub = { mode: "none", entry: { app: "./app.js" } }

      rspackIndex.baseConfig = stub

      const result = rspackIndex.generateRspackConfig()

      expect(result).toStrictEqual(
        expect.objectContaining({ mode: "none", entry: { app: "./app.js" } })
      )
      const requested = requireOrError.mock.calls.map((call) => call[0])
      expect(requested).not.toContain("rspack-manifest-plugin")
    })
  })

  // The compiled-output specs cover the normal NODE_ENV path where
  // environments/<env>.js exists. Source-level Jest runs only have the .ts env
  // files, so they intentionally exercise the missing-env fallback above.
})
