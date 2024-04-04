/* global test expect, describe, afterAll, beforeEach */

const { chdirTestApp, resetEnv } = require('../../../package/utils/helpers')
const rootPath = process.cwd()
chdirTestApp()

describe('Development specific config', () => {
  beforeEach(() => {
    jest.resetModules()
    resetEnv()
    process.env['NODE_ENV'] = 'development'
  })
  afterAll(() => process.chdir(rootPath))

  describe('with config.useContentHash = true', () => {
    test('sets filename to use contentHash', () => {
      const config = require("../../../package/config");
      config.useContentHash = true
      const environmentConfig = require('../../../package/environments/development')

      expect(environmentConfig.output.filename).toEqual('js/[name]-[contenthash].js')
      expect(environmentConfig.output.chunkFilename).toEqual(
        'js/[name]-[contenthash].chunk.js'
      )
    })
  })

  describe('with config.useContentHash = false', () => {
    test('sets filename without using contentHash', () => {
      const config = require("../../../package/config");
      config.useContentHash = false
      const environmentConfig = require('../../../package/environments/development')

      expect(environmentConfig.output.filename).toEqual('js/[name].js')
      expect(environmentConfig.output.chunkFilename).toEqual(
        'js/[name].chunk.js'
      )
    })
  })

  describe('with unset config.useContentHash', () => {
    test('sets filename without using contentHash', () => {
      const config = require("../../../package/config");
      delete config.useContentHash
      const environmentConfig = require('../../../package/environments/development')

      expect(environmentConfig.output.filename).toEqual('js/[name].js')
      expect(environmentConfig.output.chunkFilename).toEqual(
        'js/[name].chunk.js'
      )
    })
  })
})
