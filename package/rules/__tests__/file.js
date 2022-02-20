const file = require('../file')

describe('file', () => {
  test('test expected file types', () => {
    const types = [
      '.bmp',
      '.gif',
      '.jpg',
      '.jpeg',
      '.png',
      '.tiff',
      '.ico',
      '.avif',
      '.webp',
      '.eot',
      '.otf',
      '.ttf',
      '.woff',
      '.woff2',
      '.svg',
    ]
    types.forEach(type => expect(file.test.test(type)).toBe(true))
  })

  test('exclude expected file types', () => {
    const types = [
      '.js',
      '.mjs',
      '.jsx',
      '.ts',
      '.tsx',
    ]
    types.forEach(type => expect(file.exclude.test(type)).toBe(true))
  })
})
