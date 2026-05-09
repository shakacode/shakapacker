describe("index side effects", () => {
  const mockEnsureManifestExists = () => {
    const ensureManifestExists = jest.fn()

    jest.doMock("../../package/utils/ensureManifestExists", () => ({
      __esModule: true,
      default: ensureManifestExists
    }))

    return ensureManifestExists
  }

  test("does not initialize webpack plugins when only requiring the package index", () => {
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()

      require("../../package/index")

      expect(ensureManifestExists).not.toHaveBeenCalled()
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

  test("lazily exposes baseConfig with the expected shape", () => {
    jest.isolateModules(() => {
      const ensureManifestExists = mockEnsureManifestExists()

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
})
