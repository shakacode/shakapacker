/* test expect, describe, afterAll, beforeEach */

const { resolve } = require('path')
const { chdirWebpackerTestApp, resetEnv } = require('../utils/helpers')

const rootPath = process.cwd()
chdirWebpackerTestApp()

describe('Backward Compatibility - Development environment', () => {
  beforeEach(() => jest.resetModules() && resetEnv())
  afterAll(() => process.chdir(rootPath))

  describe('generateWebpackConfig', () => {
    beforeEach(() => jest.resetModules())

    test('should use development config and environment including devServer if WEBPACK_SERVE', () => {
      process.env.RAILS_ENV = 'development'
      process.env.NODE_ENV = 'development'
      process.env.WEBPACK_SERVE = 'true'
      const { generateWebpackConfig } = require('../index')

      const webpackConfig = generateWebpackConfig()

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')
    })

    test('should use development config and environment if WEBPACK_SERVE', () => {
      process.env.RAILS_ENV = 'development'
      process.env.NODE_ENV = 'development'
      process.env.WEBPACK_SERVE = undefined
      const { generateWebpackConfig } = require('../index')

      const webpackConfig = generateWebpackConfig()

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')
      expect(webpackConfig.devServer).toEqual(undefined)
    })
  })

  describe('globalMutableWebpackConfig', () => {
    beforeEach(() => jest.resetModules())

    test('should use development config and environment including devServer if WEBPACK_SERVE', () => {
      process.env.RAILS_ENV = 'development'
      process.env.NODE_ENV = 'development'
      process.env.WEBPACK_SERVE = 'true'
      const { globalMutableWebpackConfig: webpackConfig } = require('../index')

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')
    })

    test('should use development config and environment if WEBPACK_SERVE', () => {
      process.env.RAILS_ENV = 'development'
      process.env.NODE_ENV = 'development'
      process.env.WEBPACK_SERVE = undefined
      const { globalMutableWebpackConfig: webpackConfig } = require('../index')

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')
      expect(webpackConfig.devServer).toEqual(undefined)
    })
  })
})
