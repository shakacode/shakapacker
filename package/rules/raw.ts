const config = require("../config")

const rspackRawConfig = () => ({
  resourceQuery: /raw/,
  type: "asset/source"
})

const webpackRawConfig = () => ({
  // Match .html files OR any file with ?raw query parameter
  test: /\.html$/,
  exclude: /\.(js|mjs|jsx|ts|tsx)$/,
  resourceQuery: /raw/,
  type: "asset/source"
})

export =
  config.assets_bundler === "rspack" ? rspackRawConfig() : webpackRawConfig()
