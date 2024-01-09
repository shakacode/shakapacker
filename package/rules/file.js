const { dirname } = require('path')
const { includePaths } = require('../config')

module.exports = {
  test: /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|eot|otf|ttf|woff|woff2|svg)$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  type: 'asset/resource',
  generator: {
    filename: (pathData) => {
      const path = dirname(pathData.filename)
      const includePath = includePaths.find((includePath) => path.includes(includePath))

      const folders = path
        .replace(`${includePath}`, '')
        .split('/')
        .filter(Boolean)

      const foldersWithStatic = ['static', ...folders].join('/')
      return `${foldersWithStatic}/[name]-[hash][ext][query]`
    }
  }
}
