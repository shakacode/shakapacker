describe("package/bin/shakapacker-config", () => {
  let originalArgv
  let mockExit
  let mockError

  beforeEach(() => {
    jest.resetModules()
    originalArgv = process.argv
    process.argv = ["node", "shakapacker-config"]
    mockExit = jest.spyOn(process, "exit").mockImplementation(() => {})
    mockError = jest.spyOn(console, "error").mockImplementation(() => {})
  })

  afterEach(() => {
    process.argv = originalArgv
    mockExit.mockRestore()
    mockError.mockRestore()
  })

  test("prints non-Error rejections as strings", async () => {
    const plainFailure = { toString: () => "plain failure" }

    jest.doMock(require.resolve("../../../package/configExporter"), () => ({
      run: jest.fn(() => Promise.reject(plainFailure))
    }))

    require("../../../package/bin/shakapacker-config.cjs")
    await new Promise((resolve) => {
      setImmediate(resolve)
    })

    expect(mockError).toHaveBeenCalledWith("plain failure")
    expect(mockExit).toHaveBeenCalledWith(1)
  })
})
