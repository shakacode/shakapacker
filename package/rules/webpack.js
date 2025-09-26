/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

module.exports = [
  require("./raw"),
  require("./file"),
  require("./css"),
  require("./sass"),
  require("./babel"),
  require("./swc"),
  require("./esbuild"),
  require("./erb"),
  require("./coffee"),
  require("./less"),
  require("./stylus")
].filter(Boolean)
