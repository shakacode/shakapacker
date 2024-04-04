const raw = require('../raw')

describe('raw', () => {
  test('test expected file types', () => {
    expect(raw.test.test('.html')).toBe(true)
  })

  test('exclude expected file types', () => {
    const types = [
      '.js',
      '.mjs',
      '.jsx',
      '.ts',
      '.tsx',
    ]
    types.forEach(type => expect(raw.exclude.test(type)).toBe(true))
  })
})
