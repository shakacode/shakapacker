/* test expect, describe, afterAll, beforeEach */

const { resolve } = require('path')
const { chdirTestApp, resetEnv } = require('../utils/helpers')

const rootPath = process.cwd()
chdirTestApp()

describe('Development environment', () => {
  beforeEach(() => jest.resetModules() && resetEnv())
  afterAll(() => process.chdir(rootPath))

  describe('webpackConfig', () => {
    beforeEach(() => jest.resetModules())

    test('should use development config and environment including devServer if WEBPACK_SERVE', () => {
      process.env.RAILS_ENV = 'development'
      process.env.NODE_ENV = 'development'
      process.env.WEBPACK_SERVE = 'true'
      const { webpackConfig: getWebpackConfig } = require('../index')

      const webpackConfig = getWebpackConfig()

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')
    })

    test('should use development config and environment if WEBPACK_SERVE', () => {
      process.env.RAILS_ENV = 'development'
      process.env.NODE_ENV = 'development'
      process.env.WEBPACK_SERVE = undefined
      const { webpackConfig: getWebpackConfig } = require('../index')

      const webpackConfig = getWebpackConfig()

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')
      expect(webpackConfig.devServer).toEqual(undefined)
    })
  })
})
