import { loaderMatches } from "../utils/helpers"
import config from "../config"
const javascriptTranspiler = config.javascript_transpiler
import { isProduction } from "../env"
import jscommon from "./jscommon"

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
