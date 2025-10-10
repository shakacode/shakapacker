import { canProcess } from "../utils/helpers"

export default canProcess("coffee-loader", (resolvedPath: string) => ({
  test: /\.coffee(\.erb)?$/,
  use: [{ loader: resolvedPath }]
}))
