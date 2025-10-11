import raw from "./raw"
import file from "./file"
import css from "./css"
import sass from "./sass"
import babel from "./babel"
import swc from "./swc"
import esbuild from "./esbuild"
import erb from "./erb"
import coffee from "./coffee"
import less from "./less"
import stylus from "./stylus"

export default [
  raw,
  file,
  css,
  sass,
  babel,
  swc,
  esbuild,
  erb,
  coffee,
  less,
  stylus
].filter(Boolean)
