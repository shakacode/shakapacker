describe("index side effects", () => {
  afterEach(() => {
    jest.resetModules()
  })

  test("does not initialize webpack plugins when only requiring the package index", () => {
    jest.isolateModules(() => {
      const ensureManifestExists = jest.fn()

      jest.doMock("../../package/utils/ensureManifestExists", () => ({
        __esModule: true,
        default: ensureManifestExists
      }))

      require("../../package/index")

      expect(ensureManifestExists).not.toHaveBeenCalled()
    })
  })
})
