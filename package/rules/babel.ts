import { loaderMatches } from "../utils/helpers"
import config from "../config"
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { isProduction } = require("../env")
import jscommon from "./jscommon"

const { javascript_transpiler: javascriptTranspiler } = config

export default loaderMatches(javascriptTranspiler, "babel", () => ({
  test: /\.(js|jsx|mjs|ts|tsx|coffee)?(\.erb)?$/,
  ...jscommon,
  use: [
    {
      loader: require.resolve("babel-loader"),
      options: {
        cacheDirectory: true,
        cacheCompression: isProduction,
        compact: isProduction
      }
    }
  ]
}))
