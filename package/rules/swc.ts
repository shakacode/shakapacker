import { loaderMatches } from "../utils/helpers"
import { getSwcLoaderConfig } from "../swc"
import { javascript_transpiler: javascriptTranspiler } from "../config"
import jscommon from "./jscommon"

export = loaderMatches(javascriptTranspiler, "swc", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }: { resource: string }) => getSwcLoaderConfig(resource)
}))
