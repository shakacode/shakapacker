import { loaderMatches } from "../utils/helpers"
import { getEsbuildLoaderConfig } from "../esbuild"
import config from "../config"
import jscommon from "./jscommon"

const { javascript_transpiler: javascriptTranspiler } = config

export default loaderMatches(javascriptTranspiler, "esbuild", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }: { resource: string }) => getEsbuildLoaderConfig(resource)
}))
