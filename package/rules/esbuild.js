const { loaderMatches } = require("../utils/helpers")
const { getEsbuildLoaderConfig } = require("../esbuild")
const { javascript_transpiler: javascriptTranspiler } = require("../config")
const jscommon = require("./jscommon")

module.exports = loaderMatches(javascriptTranspiler, "esbuild", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }) => getEsbuildLoaderConfig(resource)
}))
