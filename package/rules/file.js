const { dirname } = require('path')
const { includePaths } = require('../config')

module.exports = {
  test: /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|eot|otf|ttf|woff|woff2|svg)$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  type: 'asset/resource',
  generator: {
    filename: (pathData) => {
      let path = dirname(pathData.filename)

      includePaths.forEach((includePath) => {
        path = path.replace(`${includePath}`, '')
      })

      const folders = path.split('/').filter(Boolean)
      const foldersWithStatic = ['static', ...folders].join('/')

      return `${foldersWithStatic}/[name]-[hash][ext][query]`
    }
  }
}
