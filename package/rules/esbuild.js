const { loaderMatches } = require("../utils/helpers")
const { getEsbuildLoaderConfig } = require("../esbuild")
const { webpack_loader: webpackLoader } = require("../config")
const jscommon = require("./jscommon")

module.exports = loaderMatches(webpackLoader, "esbuild", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }) => getEsbuildLoaderConfig(resource)
}))
