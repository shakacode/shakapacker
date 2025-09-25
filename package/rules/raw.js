const config = require("../config")

const rspackRawConfig = () => ({
  resourceQuery: /raw/,
  type: "asset/source"
})

const webpackRawConfig = () => ({
  test: /\.html$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  type: "asset/source"
})

module.exports =
  config.assets_bundler === "rspack" ? rspackRawConfig() : webpackRawConfig()
