import { loaderMatches } from "../utils/helpers"
import { getSwcLoaderConfig } from "../swc"
import config from "../config"
const javascriptTranspiler = config.javascript_transpiler
import jscommon from "./jscommon"

export default loaderMatches(javascriptTranspiler, "swc", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }: { resource: string }) => getSwcLoaderConfig(resource)
}))
