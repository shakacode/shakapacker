/* global test expect, describe */

const { chdirWebpackerTestApp, resetEnv } = require('../utils/helpers')

const rootPath = process.cwd()
chdirWebpackerTestApp()

describe('Backward Compatibility - Env', () => {
  beforeEach(() => jest.resetModules() && resetEnv())
  afterAll(() => process.chdir(rootPath))

  test('with NODE_ENV and RAILS_ENV set to development', () => {
    process.env.RAILS_ENV = 'development'
    process.env.NODE_ENV = 'development'
    expect(require('../env')).toEqual({
      railsEnv: 'development',
      nodeEnv: 'development',
      isProduction: false,
      isDevelopment: true,
      runningWebpackDevServer: false
    })
  })

  test('with undefined NODE_ENV and RAILS_ENV set to development', () => {
    process.env.RAILS_ENV = 'development'
    delete process.env.NODE_ENV
    expect(require('../env')).toEqual({
      railsEnv: 'development',
      nodeEnv: 'production',
      isProduction: true,
      isDevelopment: false,
      runningWebpackDevServer: false
    })
  })

  test('with undefined NODE_ENV and RAILS_ENV', () => {
    delete process.env.NODE_ENV
    delete process.env.RAILS_ENV
    expect(require('../env')).toEqual({
      railsEnv: 'production',
      nodeEnv: 'production',
      isProduction: true,
      isDevelopment: false,
      runningWebpackDevServer: false
    })
  })

  test('with a non-standard environment', () => {
    process.env.RAILS_ENV = 'staging'
    process.env.NODE_ENV = 'staging'
    expect(require('../env')).toEqual({
      railsEnv: 'staging',
      nodeEnv: 'production',
      isProduction: true,
      isDevelopment: false,
      runningWebpackDevServer: false
    })
  })
})
