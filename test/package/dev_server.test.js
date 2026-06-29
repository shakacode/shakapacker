const { chdirTestApp } = require("../helpers")

const rootPath = process.cwd()
chdirTestApp()

const envKeys = [
  "NODE_ENV",
  "RAILS_ENV",
  "SHAKAPACKER_DEV_SERVER_HOST",
  "SHAKAPACKER_DEV_SERVER_PORT",
  "SHAKAPACKER_DEV_SERVER_DISABLE_HOST_CHECK",
  "TEST_SHAKAPACKER_DEV_SERVER_HOST",
  "TEST_SHAKAPACKER_DEV_SERVER_PORT"
]

describe("DevServer", () => {
  let originalEnv

  beforeEach(() => {
    originalEnv = Object.fromEntries(
      envKeys.map((key) => [key, process.env[key]])
    )
    jest.resetModules()
  })

  afterEach(() => {
    envKeys.forEach((key) => {
      if (originalEnv[key] === undefined) {
        delete process.env[key]
      } else {
        process.env[key] = originalEnv[key]
      }
    })
  })

  afterAll(() => process.chdir(rootPath))

  test("with NODE_ENV and RAILS_ENV set to development", () => {
    process.env.NODE_ENV = "development"
    process.env.RAILS_ENV = "development"
    process.env.SHAKAPACKER_DEV_SERVER_HOST = "0.0.0.0"
    process.env.SHAKAPACKER_DEV_SERVER_PORT = 5000
    process.env.SHAKAPACKER_DEV_SERVER_DISABLE_HOST_CHECK = false

    const devServer = require("../../package/dev_server")
    expect(devServer).toBeDefined()
    expect(devServer.host).toBe("0.0.0.0")
    expect(devServer.port).toBe("5000")
    expect(devServer.disable_host_check).toBe(false)
  })

  test("with custom env prefix", () => {
    // Set NODE_ENV/RAILS_ENV before requiring config: config resolves
    // dev_server from shakapacker.yml at load time, and production has no
    // dev_server section. Without this, a reordered run (e.g. --randomize)
    // where the production test ran first leaks NODE_ENV=production here and
    // config.dev_server is undefined.
    process.env.NODE_ENV = "development"
    process.env.RAILS_ENV = "development"
    process.env.TEST_SHAKAPACKER_DEV_SERVER_HOST = "0.0.0.0"
    process.env.TEST_SHAKAPACKER_DEV_SERVER_PORT = 5000

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
