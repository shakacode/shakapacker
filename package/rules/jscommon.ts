import { resolve } from "path"
import { realpathSync } from "fs"
import config from "../config"

const { source_path: sourcePath, additional_paths: additionalPaths } = config

const inclusions = [sourcePath, ...additionalPaths].map((p: string) => {
  try {
    return realpathSync(p)
  } catch (e) {
    return resolve(p)
  }
})

export default {
  include: inclusions,
  exclude: [
    {
      // exclude all node_modules from running through babel-loader
      and: [resolve("node_modules")],
      // Do not exclude inclusions, as otherwise these won't be transpiled
      not: [...inclusions]
    }
  ]
}
