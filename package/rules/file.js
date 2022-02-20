const { dirname, join } = require('path')
const { source_path: sourcePath } = require('../config')

module.exports = {
  test: /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|eot|otf|ttf|woff|woff2|svg)$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  type: 'asset/resource',
  generator: {
    filename: (pathData) => {
      const folders = dirname(pathData.filename)
        .replace(`${sourcePath}/`, '')
        .split('/')
        .slice(1)

      const foldersWithStatic = join('static', ...folders)
      return `${foldersWithStatic}/[name]-[hash][ext][query]`
    }
  }
}
