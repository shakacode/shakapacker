const { dirname } = require('path')
const { source_path: sourcePath } = require('../config')

module.exports = {
  test: /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|eot|otf|ttf|woff|woff2|svg)$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  type: 'asset/resource',
  generator: {
    filename: (pathData) => {
      const folders = dirname(pathData.filename)
        .replace(`${sourcePath}`, '')
        .split('/')
        .filter(Boolean)

      const foldersWithStatic = ['static', ...folders].join('/')
      return `${foldersWithStatic}/[name]-[hash][ext][query]`
    }
  }
}
