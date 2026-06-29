const { chdirTestApp, resetEnv } = require("../helpers")

const rootPath = process.cwd()
chdirTestApp()

describe("DevServer", () => {
  beforeEach(() => {
    jest.resetModules()
    resetEnv()
  })

  afterAll(() => process.chdir(rootPath))

  test("with NODE_ENV and RAILS_ENV set to development", () => {
    process.env.NODE_ENV = "development"
    process.env.RAILS_ENV = "development"
    process.env.SHAKAPACKER_DEV_SERVER_HOST = "0.0.0.0"
    process.env.SHAKAPACKER_DEV_SERVER_PORT = "5000"
    process.env.SHAKAPACKER_DEV_SERVER_DISABLE_HOST_CHECK = "false"

    const devServer = require("../../package/dev_server")
    expect(devServer).toBeDefined()
    expect(devServer.host).toBe("0.0.0.0")
    expect(devServer.port).toBe("5000")
    expect(devServer.disable_host_check).toBe(false)
  })

  test("with custom env prefix", () => {
    // NODE_ENV must precede require: config reads shakapacker.yml at load time; production has no dev_server.
    process.env.NODE_ENV = "development"
    process.env.RAILS_ENV = "development"
    process.env.TEST_SHAKAPACKER_DEV_SERVER_HOST = "0.0.0.0"
    process.env.TEST_SHAKAPACKER_DEV_SERVER_PORT = "5000"

    const config = require("../../package/config")
    config.dev_server.env_prefix = "TEST_SHAKAPACKER_DEV_SERVER"

    const devServer = require("../../package/dev_server")
    expect(devServer).toBeDefined()
    expect(devServer.host).toBe("0.0.0.0")
    expect(devServer.port).toBe("5000")
  })

  test("with NODE_ENV and RAILS_ENV set to production", () => {
    process.env.RAILS_ENV = "production"
    process.env.NODE_ENV = "production"
    expect(require("../../package/dev_server")).toStrictEqual({})
  })
})
