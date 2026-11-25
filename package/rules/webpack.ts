/* eslint import/no-dynamic-require: 0 */

// `filter(Boolean)` is for the preprocessor rules, which are null when their
// loader is not installed. `./css` always yields a rule.
export = [
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
