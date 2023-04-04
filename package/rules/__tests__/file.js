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

  test('correct generated output path is returned for top level files', () => {
    const pathData = {
      filename: 'app/javascript/image.svg',
    };
    expect(file.generator.filename(pathData)).toEqual(
      'static/[name]-[hash][ext][query]'
    );
  });

  test('correct generated output path is returned for nested files', () => {
    const pathData = {
      filename: 'app/javascript/images/image.svg',
    };
    expect(file.generator.filename(pathData)).toEqual(
      'static/images/[name]-[hash][ext][query]'
    );
  })

  test('correct generated output path is returned for deeply nested files', () => {
    const pathData = {
      filename: 'app/javascript/images/nested/deeply/image.svg',
    };
    expect(file.generator.filename(pathData)).toEqual(
      'static/images/nested/deeply/[name]-[hash][ext][query]'
    );
  });
})
