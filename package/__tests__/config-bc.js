/* global test expect, describe */
const { resolve } = require('path')
const { chdirWebpackerTestApp, resetEnv } = require('../utils/helpers')

const rootPath = process.cwd()
chdirWebpackerTestApp()

const config = require('../config')

describe('Backward Compatibility - Config', () => { 
  beforeEach(() => jest.resetModules() && resetEnv())
  afterAll(() => process.chdir(rootPath))

  test('x public path with asset host', () => {
    process.env.RAILS_ENV = 'development'
    process.env.WEBPACKER_ASSET_HOST = 'http://foo.com/'
    const config = require('../config')

    expect(config.publicPath).toEqual('http://foo.com/packs/')
  })

  test('x should allow overriding manifestPath', () => {
    process.env.WEBPACKER_CONFIG = 'config/webpacker_manifest_path.yml'
    const config = require('../config')
    expect(config.manifestPath).toEqual(resolve('app/packs/manifest.json'))
  })
})
