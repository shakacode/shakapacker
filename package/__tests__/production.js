/* test expect, describe, afterAll, beforeEach */

const { resolve } = require('path')
const { chdirTestApp, chdirCwd } = require('../utils/helpers')

const rootPath = process.cwd()
chdirTestApp()

describe('Production environment', () => {
  afterAll(() => process.chdir(rootPath))

  describe('generateWebpackConfig', () => {
    beforeEach(() => jest.resetModules())

    test('should use production config and environment', () => {
      process.env.RAILS_ENV = 'production'
      process.env.NODE_ENV = 'production'

      const { generateWebpackConfig } = require('../index')

      const webpackConfig = generateWebpackConfig()

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')

      expect(webpackConfig).toMatchObject({
        devtool: 'source-map',
        stats: 'normal'
      })
    })
  })

  describe('globalMutableWebpackConfig', () => {
    beforeEach(() => jest.resetModules())

    test('should use production config and environment', () => {
      process.env.RAILS_ENV = 'production'
      process.env.NODE_ENV = 'production'

      const { globalMutableWebpackConfig: webpackConfig } = require('../index')

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')

      expect(webpackConfig).toMatchObject({
        devtool: 'source-map',
        stats: 'normal'
      })
    })
  })
})
