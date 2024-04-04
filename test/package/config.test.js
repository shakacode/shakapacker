/* global test expect, describe */

const { chdirTestApp, resetEnv } = require('../../package/utils/helpers')
const { resolve } = require('path')

const rootPath = process.cwd()
chdirTestApp()

const config = require('../../package/config')

describe('Config', () => {
  beforeEach(() => jest.resetModules() && resetEnv())
  afterAll(() => process.chdir(rootPath))

  test('public path', () => {
    process.env.RAILS_ENV = 'development'
    const config = require('../../package/config')
    expect(config.publicPath).toEqual('/packs/')
  })

  test('public path with asset host', () => {
    process.env.RAILS_ENV = 'development'
    process.env.SHAKAPACKER_ASSET_HOST = 'http://foo.com/'
    const config = require('../../package/config')
    expect(config.publicPath).toEqual('http://foo.com/packs/')
  })

  test('should return additional paths as listed in app config, with resolved paths', () => {
    expect(config.additional_paths).toEqual([
      'app/assets',
      '/etc/yarn',
      'some.config.js',
      'app/elm'
    ])
  })

  test('should default manifestPath to the public dir', () => {
    expect(config.manifestPath).toEqual(resolve('public/packs/manifest.json'))
  })

  test('should allow overriding manifestPath', () => {
    process.env.SHAKAPACKER_CONFIG = 'config/shakapacker_manifest_path.yml'
    const config = require('../../package/config')
    expect(config.manifestPath).toEqual(resolve('app/javascript/manifest.json'))
  })
})
