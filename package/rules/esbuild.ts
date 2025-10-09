import { loaderMatches } from "../utils/helpers"
import { getEsbuildLoaderConfig } from "../esbuild"
import config from "../config"
const javascriptTranspiler = config.javascript_transpiler
import jscommon from "./jscommon"

export default loaderMatches(javascriptTranspiler, "esbuild", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }: { resource: string }) => getEsbuildLoaderConfig(resource)
}))
