const { resolve } = require('path')
const { realpathSync } = require('fs')
const { loaderMatches } = require('../utils/helpers')

const {
  source_path: sourcePath,
  additional_paths: additionalPaths,
  webpack_loader: webpackLoader
} = require('../config')
const { isProduction } = require('../env')

module.exports = loaderMatches(webpackLoader, 'babel', () => ({
    test: /\.(js|jsx|mjs|ts|tsx|coffee)?(\.erb)?$/,
    include: [sourcePath, ...additionalPaths].map((p) => {
      try {
        return realpathSync(p)
      } catch (e) {
        return resolve(p)
      }
    }),
    exclude: /node_modules/,
    use: [
      {
        loader: require.resolve('babel-loader'),
        options: {
          cacheDirectory: true,
          cacheCompression: isProduction,
          compact: isProduction
        }
      }
    ]
  }))
