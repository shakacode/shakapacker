import { loaderMatches } from "../utils/helpers"
import { getEsbuildLoaderConfig } from "../esbuild"
import { javascript_transpiler: javascriptTranspiler } from "../config"
import jscommon from "./jscommon"

export = loaderMatches(javascriptTranspiler, "esbuild", () => ({
  test: /\.(ts|tsx|js|jsx|mjs|coffee)?(\.erb)?$/,
  ...jscommon,
  use: ({ resource }: { resource: string }) => getEsbuildLoaderConfig(resource)
}))
