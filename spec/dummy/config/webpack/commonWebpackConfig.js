// Common configuration applying to client and server configuration

const { requireShakapacker } = require('../shakapacker_package')

const { generateWebpackConfig, merge } = requireShakapacker()
const commonOptions = {
  resolve: {
    extensions: ['.css', '.ts', '.tsx']
  }
}

const ignoreWarningsConfig = {
  ignoreWarnings: [/Module not found: Error: Can't resolve 'react-dom\/client'/]
}
// Copy the object using merge b/c the baseClientWebpackConfig and commonOptions are mutable globals
// const commonWebpackConfig = () => (merge({}, baseClientWebpackConfig, commonOptions))
const commonWebpackConfig = () =>
  generateWebpackConfig(merge(commonOptions, ignoreWarningsConfig))

module.exports = commonWebpackConfig
