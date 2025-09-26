const { loaderMatches } = require("../utils/helpers")
const { getSwcLoaderConfig } = require("../swc")
const { javascript_transpiler: javascriptTranspiler } = require("../config")
const jscommon = require("./jscommon")

module.exports = loaderMatches(javascriptTranspiler, "swc", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }) => getSwcLoaderConfig(resource)
}))
