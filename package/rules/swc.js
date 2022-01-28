const { resolve } = require('path')
const { realpathSync } = require('fs')
const { loaderMatches } = require('../utils/helpers')
const { getSwcLoaderConfig } = require('../swc')

const {
  source_path: sourcePath,
  additional_paths: additionalPaths,
  webpack_loader: webpackLoader
} = require('../config')

module.exports = loaderMatches(webpackLoader, 'swc', () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  include: [sourcePath, ...additionalPaths].map((p) => {
    try {
      return realpathSync(p)
    } catch (e) {
      return resolve(p)
    }
  }),
  exclude: /node_modules/,
  use: ({ resource }) => getSwcLoaderConfig(resource)
}))
