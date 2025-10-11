import { loaderMatches } from "../utils/helpers"
import { getSwcLoaderConfig } from "../swc"
import config from "../config"
import jscommon from "./jscommon"

const { javascript_transpiler: javascriptTranspiler } = config

export default loaderMatches(javascriptTranspiler, "swc", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }: { resource: string }) => getSwcLoaderConfig(resource)
}))
