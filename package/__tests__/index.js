const index = require('../index')
const { test } = require('../rules/raw')

describe('index', () => {
  test('exports webpack-merge v5 functions', () => {
    expect(index.merge).toBeInstanceOf(Function)
    expect(index.mergeWithRules).toBeInstanceOf(Function)
    expect(index.mergeWithCustomize).toBeInstanceOf(Function)
  })

  test('webpackConfig returns an immutable object', () => {
    const { webpackConfig: getWebpackConfig } = require('../index')

    const webpackConfig1 = getWebpackConfig()
    const webpackConfig2 = getWebpackConfig()

    webpackConfig1.newKey = 'new value'
    webpackConfig1.output.path = 'new path'

    expect(webpackConfig2).not.toHaveProperty('newKey')
    expect(webpackConfig2.output.path).not.toEqual('new value')
  })
})
