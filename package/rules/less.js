const path = require('path')
const { canProcess } = require('../utils/helpers')
const getStyleRule = require('../utils/get_style_rule')
const { includePaths } = require('../config')

module.exports = canProcess('less-loader', (resolvedPath) =>
  getStyleRule(/\.(less)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        lessOptions: {
          paths: [
            path.resolve(__dirname, 'node_modules'),
            ...includePaths
          ]
        },
        sourceMap: true
      }
    }
  ])
)
