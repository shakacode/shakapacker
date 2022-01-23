const { resolve } = require('path')
const { realpathSync } = require('fs')

const {
  source_path: sourcePath,
  additional_paths: additionalPaths
} = require('../config')
const { isProduction } = require('../env')

module.exports = [
  {
    test: /\.(js|jsx|mjs|coffee)?(\.erb)?$/,
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
        loader: require.resolve('swc-loader'),
        options: {
          jsc: {
            parser: {
              syntax: 'ecmascript',
              jsx: true,
              transform: {
                react: {
                  runtime: 'automatic',
                  refresh: true
                }
              }
            }
          },
          sourceMaps: true
        }
      }
    ]
  },
  {
    test: /\.(ts|tsx)?(\.erb)?$/,
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
        loader: require.resolve('swc-loader'),
        options: {
          jsc: {
            parser: {
              syntax: 'typescript',
              tsx: true,
              transform: {
                react: {
                  runtime: 'automatic',
                  refresh: true
                }
              }
            }
          },
          sourceMaps: true
        }
      }
    ]
  }
]
