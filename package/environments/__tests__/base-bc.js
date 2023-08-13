/* global test expect, describe, afterAll, beforeEach */

// environment.js expects to find config/webpacker.yml and resolved modules from
// the root of a Rails project

const { resetEnv, chdirWebpackerTestApp } = require('../../utils/helpers')

const rootPath = process.cwd()
chdirWebpackerTestApp()

const { resolve } = require('path')

const baseConfig = require('../base')
const config = require("../../config");

describe('Base config', () => {
  beforeEach(() => jest.resetModules() && resetEnv())
  afterAll(() => process.chdir(rootPath))

  describe('config', () => {
    test('should return entry', () => {
      expect(baseConfig.entry.application).toEqual(
        resolve('app', 'packs', 'entrypoints', 'application.js')
      )
    })

    test('should return false for css_extract_ignore_order_warnings when using default config', () => {
      expect(config.css_extract_ignore_order_warnings).toEqual(false)
    })

    test('should return true for css_extract_ignore_order_warnings when configured', () => {
      process.env.WEBPACKER_CONFIG = 'config/webpacker_css_extract_ignore_order_warnings.yml'
      const config = require("../../config");

      expect(config.css_extract_ignore_order_warnings).toEqual(true)
    })

    test('should return only 2 entry points with config.nested_entries == false', () => {
      expect(config.nested_entries).toEqual(false)

      expect(baseConfig.entry.multi_entry.sort()).toEqual([
        resolve('app', 'packs', 'entrypoints', 'multi_entry.css'),
        resolve('app', 'packs', 'entrypoints', 'multi_entry.js')
      ])
      expect(baseConfig.entry['generated/something']).toEqual(undefined)
    })

    test('should returns top level and nested entry points with config.nested_entries == true', () => {
      process.env.WEBPACKER_CONFIG = 'config/webpacker_nested_entries.yml'
      const config = require("../../config");
      const baseConfig = require('../base')

      expect(config.nested_entries).toEqual(true)

      expect(baseConfig.entry.application).toEqual(
        resolve('app', 'packs', 'entrypoints', 'application.js')
      )
      expect(baseConfig.entry.multi_entry.sort()).toEqual([
        resolve('app', 'packs', 'entrypoints', 'multi_entry.css'),
        resolve('app', 'packs', 'entrypoints', 'multi_entry.js')
      ])
      expect(baseConfig.entry['generated/something']).toEqual(
        resolve('app', 'packs', 'entrypoints', 'generated', 'something.js')
      )
    })

    test('should return output', () => {
      expect(baseConfig.output.filename).toEqual('js/[name]-[contenthash].js')
      expect(baseConfig.output.chunkFilename).toEqual(
        'js/[name]-[contenthash].chunk.js'
      )
    })

    test('should return default loader rules for each file in config/loaders', () => {
      const rules = require('../../rules')

      const defaultRules = Object.keys(rules)
      const configRules = baseConfig.module.rules

      expect(defaultRules.length).toEqual(3)
      expect(configRules.length).toEqual(3)
    })

    test('should return default plugins', () => {
      expect(baseConfig.plugins.length).toEqual(2)
    })

    test('should return default resolveLoader', () => {
      expect(baseConfig.resolveLoader.modules).toEqual(['node_modules'])
    })

    test('should return default resolve.modules with additions', () => {
      expect(baseConfig.resolve.modules).toEqual([
        resolve('app', 'packs'),
        resolve('app/assets'),
        resolve('/etc/yarn'),
        resolve('some.config.js'),
        resolve('app/elm'),
        'node_modules'
      ])
    })

    test('returns plugins property as Array', () => {
      expect(baseConfig.plugins).toBeInstanceOf(Array)
    })
  })
})
