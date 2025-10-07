import { canProcess } from "../utils/helpers"

export = canProcess("coffee-loader", (resolvedPath: string) => ({
  test: /\.coffee(\.erb)?$/,
  use: [{ loader: resolvedPath }]
}))
