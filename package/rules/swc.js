const { loaderMatches } = require("../utils/helpers")
const { getSwcLoaderConfig } = require("../swc")
const { webpack_loader: webpackLoader } = require("../config")
const jscommon = require("./jscommon")

module.exports = loaderMatches(webpackLoader, "swc", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }) => getSwcLoaderConfig(resource)
}))
