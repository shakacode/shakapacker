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

  test("assigning to baseConfig throws an informative TypeError", () => {
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")

      expect(() => {
        shakapacker.baseConfig = {}
      }).toThrow(/shakapacker\.baseConfig is read-only/)
    })
  })

  test("baseConfig can be overridden via Object.defineProperty", () => {
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

  test("assigning to rules throws an informative TypeError", () => {
    jest.isolateModules(() => {
      mockEnsureManifestExists()

      const shakapacker = require("../../package/index")

      expect(() => {
        shakapacker.rules = []
      }).toThrow(/shakapacker\.rules is read-only/)
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
})
