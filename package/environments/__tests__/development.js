/* global test expect, describe, afterAll, beforeEach */

process.env['RAILS_ENV'] = 'development'

const { chdirTestApp, resetEnv } = require('../../utils/helpers')
const rootPath = process.cwd()
chdirTestApp()

describe('Development specific config', () => {
  beforeEach(() => jest.resetModules() && resetEnv())
  afterAll(() => process.chdir(rootPath))

  describe('with config.useContentHash = true', () => {
    test('should return output with contentHash', () => {
      const config = require("../../config");
      config.useContentHash = true
      const environmnetConfig = require('../development')

      expect(environmnetConfig.output.filename).toEqual('js/[name]-[contenthash].js')
      expect(environmnetConfig.output.chunkFilename).toEqual(
        'js/[name]-[contenthash].chunk.js'
      )
    })
  })

  describe('with config.useContentHash = false', () => {
    test('should return output with contentHash', () => {
      const config = require("../../config");
      config.useContentHash = false
      const environmnetConfig = require('../development')

      expect(environmnetConfig.output.filename).toEqual('js/[name].js')
      expect(environmnetConfig.output.chunkFilename).toEqual(
        'js/[name].chunk.js'
      )
    })
  })

  describe('with unset config.useContentHash', () => {
    test('should return output with contentHash', () => {
      const config = require("../../config");
      delete config.useContentHash
      const environmnetConfig = require('../development')

      expect(environmnetConfig.output.filename).toEqual('js/[name].js')
      expect(environmnetConfig.output.chunkFilename).toEqual(
        'js/[name].chunk.js'
      )
    })
  })
})
