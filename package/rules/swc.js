const { resolve } = require('path')
const { realpathSync } = require('fs')
const { loaderMatches } = require('../utils/helpers')

const {
  source_path: sourcePath,
  additional_paths: additionalPaths,
  webpack_loader: webpackLoader
} = require('../config')
const { isDevelopment, runningWebpackDevServer } = require('../env')

const isJsxFile = (filename) => !!filename.match(/\.(jsx|tsx)?(\.erb)?$/)

const isTypescriptFile = (filename) => !!filename.match(/\.(ts|tsx)?(\.erb)?$/)

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
  use: ({ resource }) => ({
      loader: require.resolve('swc-loader'),
      options: {
        jsc: {
          parser: {
            dynamicImport: true,
            syntax: isTypescriptFile(resource) ? 'typescript' : 'ecmascript',
            [isTypescriptFile(resource) ? 'tsx' : 'jsx']: isJsxFile(resource)
          },
          transform: {
            react: {
              runtime: 'automatic',
              development: isDevelopment,
              refresh: runningWebpackDevServer && isDevelopment
            }
          }
        },
        sourceMaps: true,
        env: {
          coreJs: '3.8',
          loose: true,
          exclude: ['transform-typeof-symbol'],
          mode: 'entry'
        }
      }
    })
}))
