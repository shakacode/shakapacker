/* eslint global-require: 0 */
const { canProcess, moduleExists } = require('./helpers')
const inliningCss = require('../inliningCss')

const isModuleFile = (filename) => !!filename.match(/\.module\.\w+(\.erb)?$/i)

const getStyleRule = (test, preprocessors = []) => {
  if (moduleExists('css-loader')) {
    const tryPostcss = () =>
      canProcess('postcss-loader', (loaderPath) => ({
        loader: loaderPath,
        options: { sourceMap: true }
      }))

    // style-loader is required when using css modules with HMR on the webpack-dev-server

    const use = [
      inliningCss ? 'style-loader' : require('mini-css-extract-plugin').loader,
      {
        loader: require.resolve('css-loader'),
        options: {
          sourceMap: true,
          importLoaders: 2,
          modules: {
            mode: resourcePath => isModuleFile(resourcePath) ? 'local' : 'icss'
          }
        }
      },
      tryPostcss(),
      ...preprocessors
    ].filter(Boolean)

    return {
      test,
      use
    }
  }

  return null
}

module.exports = getStyleRule
