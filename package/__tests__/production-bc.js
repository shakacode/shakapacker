/* test expect, describe, afterAll, beforeEach */

const { resolve } = require('path')
const { chdirWebpackerTestApp } = require('../utils/helpers')

const rootPath = process.cwd()
chdirWebpackerTestApp()

describe('Backward Compatibility - Production environment', () => {
  afterAll(() => process.chdir(rootPath))

  describe('webpackConfig', () => {
    beforeEach(() => jest.resetModules())

    test('should use production config and environment', () => {
      process.env.RAILS_ENV = 'production'
      process.env.NODE_ENV = 'production'

      const { webpackConfig } = require('../index')

      expect(webpackConfig.output.path).toEqual(resolve('public', 'packs'))
      expect(webpackConfig.output.publicPath).toEqual('/packs/')

      expect(webpackConfig).toMatchObject({
        devtool: 'source-map',
        stats: 'normal'
      })
    })
  })
})
