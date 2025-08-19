// Use Rspack's built-in asset/source instead of raw-loader
module.exports = {
  resourceQuery: /raw/,
  type: "asset/source"
}