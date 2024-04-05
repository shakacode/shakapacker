const { resolve } = require("path")
const { chdirTestApp } = require("../helpers")

const rootPath = process.cwd()
chdirTestApp()

describe("Custom environment", () => {
  afterAll(() => process.chdir(rootPath))

  describe("generateWebpackConfig", () => {
    beforeEach(() => jest.resetModules())

    test("should use staging config and default production environment", () => {
      process.env.RAILS_ENV = "staging"
      delete process.env.NODE_ENV

      const { generateWebpackConfig } = require("../../package/index")

      const webpackConfig = generateWebpackConfig()

      expect(webpackConfig.output.path).toStrictEqual(
        resolve("public", "packs-staging")
      )
      expect(webpackConfig.output.publicPath).toBe("/packs-staging/")
      expect(webpackConfig).toMatchObject({
        devtool: "source-map",
        stats: "normal"
      })
    })
  })
})
