/* eslint global-require: 0 */
const { canProcess, moduleExists } = require("./helpers")
const inliningCss = require("./inliningCss")

const getStyleRule = (test, preprocessors = []) => {
  if (moduleExists("css-loader")) {
    const tryPostcss = () =>
      canProcess("postcss-loader", (loaderPath) => ({
        loader: loaderPath,
        options: { sourceMap: true }
      }))

    // Extract the first loader (usually the extraction loader) and remaining preprocessors
    const [extractionLoader, ...otherPreprocessors] = preprocessors
    
    // Fallback to mini-css-extract-plugin if no extraction loader provided (for webpack compatibility)
    const finalExtractionLoader = extractionLoader || 
      (inliningCss ? "style-loader" : require("mini-css-extract-plugin").loader)

    const use = [
      finalExtractionLoader,
      {
        loader: require.resolve("css-loader"),
        options: {
          sourceMap: true,
          importLoaders: 2,
          modules: {
            auto: true
          }
        }
      },
      tryPostcss(),
      ...otherPreprocessors
    ].filter(Boolean)

    return {
      test,
      use
    }
  }

  return null
}

module.exports = { getStyleRule }
