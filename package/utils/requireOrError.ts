/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
/* eslint @typescript-eslint/no-require-imports: 0 */
import config from "../config"

function requireOrError<T = unknown>(moduleName: string): T {
  try {
    return require(moduleName) as T
  } catch {
    throw new Error(
      `[SHAKAPACKER]: ${moduleName} is required for ${config.assets_bundler} but is not installed. View Shakapacker's documented dependencies at https://github.com/shakacode/shakapacker/tree/main/docs/peer-dependencies.md`
    )
  }
}

export default requireOrError
