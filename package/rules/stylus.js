const path = require('path')
const { canProcess } = require('../utils/helpers')
const getStyleRule = require('../utils/get_style_rule')
const { includePaths } = require('../config')

module.exports = canProcess('stylus-loader', (resolvedPath) =>
  getStyleRule(/\.(styl(us)?)(\.erb)?$/i, [
    {
      loader: resolvedPath,
      options: {
        stylusOptions: {
          include: [
            path.resolve(__dirname, 'node_modules'),
            ...includePaths
          ]
        },
        sourceMap: true
      }
    }
  ])
)
