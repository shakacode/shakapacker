describe("index side effects", () => {
  const mockEnsureManifestExists = () => {
    const ensureManifestExists = jest.fn()

    jest.doMock("../../package/utils/ensureManifestExists", () => ({
      __esModule: true,
      default: ensureManifestExists
    }))

    return ensureManifestExists
  }

  const mockWebpackPlugins = () => {
    const getPlugins = jest.fn()

    jest.doMock("../../package/plugins/webpack", () => ({
      getPlugins
    }))

    return getPlugins
  }

  // jest.doMock registrations are global and persist across jest.isolateModules
  // boundaries, so clear them after every test to keep these specs independent
  // of execution order (e.g. under --randomize).
  afterEach(() => {
    jest.dontMock("../../package/plugins/webpack")
    jest.dontMock("../../package/utils/ensureManifestExists")
    jest.dontMock("../../package/env")
  })

  test("does not initialize webpack plugins when only requiring the package index", () => {
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()
      const getPlugins = mockWebpackPlugins()

      require("../../package/index")

      expect(ensureManifestExists).not.toHaveBeenCalled()
      expect(getPlugins).not.toHaveBeenCalled()
    })
  })

  test("defines baseConfig as a configurable lazy export", () => {
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")

      expect(
        Object.getOwnPropertyDescriptor(shakapacker, "baseConfig")
      ).toStrictEqual(
        expect.objectContaining({
          configurable: true,
          enumerable: true,
          get: expect.any(Function)
        })
      )
    })
  })

  test("assigning to baseConfig overrides the lazy value without loading the real config", () => {
    // plugins/webpack is intentionally left unmocked: if the setter override did
    // not write to the same cache the getter reads, accessing baseConfig back
    // would load environments/base and call ensureManifestExists. Asserting it
    // stays uncalled proves the assignment short-circuits the lazy loader.
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()
      jest.dontMock("../../package/plugins/webpack")

      const shakapacker = require("../../package/index")
      const stub = { mode: "none", entry: {} }

      shakapacker.baseConfig = stub

      expect(shakapacker.baseConfig).toBe(stub)
      expect(ensureManifestExists).not.toHaveBeenCalled()
    })
  })

  test("assigning undefined to baseConfig caches it without loading", () => {
    // The setter overrides the cache with whatever is assigned, so even an
    // `undefined` assignment short-circuits the lazy loader: environments/base
    // is never loaded and ensureManifestExists never runs.
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()
      jest.dontMock("../../package/plugins/webpack")

      const shakapacker = require("../../package/index")

      shakapacker.baseConfig = undefined

      expect(shakapacker.baseConfig).toBeUndefined()
      expect(ensureManifestExists).not.toHaveBeenCalled()
    })
  })

  test("baseConfig can be overridden via Object.defineProperty", () => {
    // Verifies only that the export stays redefinable (`configurable: true`).
    // A value-descriptor override bypasses the setter, so it does NOT propagate
    // to `generateWebpackConfig` (which reads the lazy cache directly). Direct
    // assignment (`shakapacker.baseConfig = custom`) is the only path that
    // reaches config generation.
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")
      const stub = { mode: "none", entry: {} }

      Object.defineProperty(shakapacker, "baseConfig", {
        value: stub,
        writable: true,
        configurable: true
      })

      expect(shakapacker.baseConfig).toBe(stub)
    })
  })

  test("defines rules as a configurable lazy export", () => {
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")

      expect(
        Object.getOwnPropertyDescriptor(shakapacker, "rules")
      ).toStrictEqual(
        expect.objectContaining({
          configurable: true,
          enumerable: true,
          get: expect.any(Function)
        })
      )
    })
  })

  test("assigning to rules overrides the lazy value", () => {
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")
      const stub = [{ test: /\.stub$/, use: [] }]

      shakapacker.rules = stub

      expect(shakapacker.rules).toBe(stub)
    })
  })

  test("assigning undefined to rules caches it without loading", () => {
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")

      shakapacker.rules = undefined

      expect(shakapacker.rules).toBeUndefined()
    })
  })

  test("rules can be overridden via Object.defineProperty", () => {
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")
      const stub = [{ test: /\.stub$/, use: [] }]

      Object.defineProperty(shakapacker, "rules", {
        value: stub,
        writable: true,
        configurable: true
      })

      expect(shakapacker.rules).toBe(stub)
    })
  })

  test("lazily exposes baseConfig with the expected shape", () => {
    // Intentionally does not call mockWebpackPlugins(): this test exercises the
    // real plugin constructors (via environments/base) to verify the lazy
    // getter still produces a fully assembled config object.
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()
      jest.dontMock("../../package/plugins/webpack")

      const shakapacker = require("../../package/index")

      expect(ensureManifestExists).not.toHaveBeenCalled()
      expect(shakapacker.baseConfig).toStrictEqual(
        expect.objectContaining({
          mode: "production",
          entry: expect.any(Object),
          output: expect.objectContaining({
            filename: expect.stringMatching(/^js\/\[name\]/),
            path: expect.any(String),
            publicPath: expect.any(String)
          }),
          resolve: expect.objectContaining({
            extensions: expect.any(Array),
            modules: expect.arrayContaining(["node_modules"])
          }),
          module: expect.objectContaining({
            rules: expect.any(Array)
          }),
          plugins: expect.any(Array)
        })
      )
      expect(ensureManifestExists).toHaveBeenCalledTimes(1)
    })
  })

  test("lazily exposes rules with the expected shape", () => {
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()

      const shakapacker = require("../../package/index")

      expect(ensureManifestExists).not.toHaveBeenCalled()
      expect(shakapacker.rules).toStrictEqual(
        expect.arrayContaining([
          expect.objectContaining({
            test: expect.any(RegExp),
            use: expect.any(Array)
          })
        ])
      )
      expect(ensureManifestExists).not.toHaveBeenCalled()
    })
  })

  test("memoizes baseConfig across repeated accesses without re-running side effects", () => {
    // The module-level lazy cache is the crux of the lazy-getter
    // contract: the first access loads environments/base (running
    // ensureManifestExists once), and subsequent accesses must return the same
    // cached object without re-running that side effect. Spying on
    // ensureManifestExists gives the assertion teeth a bare `.toBe` reference
    // check (satisfied by Node's require cache alone) would lack.
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()
      jest.dontMock("../../package/plugins/webpack")

      const shakapacker = require("../../package/index")

      const first = shakapacker.baseConfig
      const second = shakapacker.baseConfig

      expect(second).toBe(first)
      expect(ensureManifestExists).toHaveBeenCalledTimes(1)
    })
  })

  test("memoizes rules across repeated accesses", () => {
    // Repeated access must return the same cached array reference rather than
    // re-deriving it from the rules module on every read; a bare reference check
    // catches a regression that mapped or cloned the rules on each access.
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")

      expect(shakapacker.rules).toBe(shakapacker.rules)
    })
  })

  test("a baseConfig override flows into generateWebpackConfig in the no-environment-file fallback", () => {
    // Exercises the `: lazyBaseConfig.get()` branch of generateWebpackConfig
    // (package/index.ts), which is only reached when no environments/<env>.js
    // file exists. Pointing nodeEnv at a missing env forces that branch, and a
    // prior `baseConfig` override must flow through to the generated config —
    // without loading the real base (ensureManifestExists stays uncalled).
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()
      jest.doMock("../../package/env", () => ({
        ...jest.requireActual("../../package/env"),
        nodeEnv: "no-such-env"
      }))

      const shakapacker = require("../../package/index")
      const stub = { mode: "none", entry: { app: "./app.js" } }

      shakapacker.baseConfig = stub

      const result = shakapacker.generateWebpackConfig()

      expect(result).toStrictEqual(
        expect.objectContaining({ mode: "none", entry: { app: "./app.js" } })
      )
      expect(ensureManifestExists).not.toHaveBeenCalled()
    })
  })

  // The compiled-output specs cover the normal NODE_ENV path where
  // environments/<env>.js exists. Source-level Jest runs only have the .ts env
  // files, so they intentionally exercise the missing-env fallback above.
})
