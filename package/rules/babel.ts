import { loaderMatches } from "../utils/helpers"
import { javascript_transpiler: javascriptTranspiler } from "../config"
import { isProduction } from "../env"
import jscommon from "./jscommon"

export = loaderMatches(javascriptTranspiler, "babel", () => ({
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
