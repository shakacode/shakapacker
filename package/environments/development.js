const { merge } = require("webpack-merge")
const config = require("../config")
const baseConfig = require("./base")
const webpackDevServerConfig = require("../webpackDevServerConfig")
const { runningWebpackDevServer } = require("../env")
const { moduleExists } = require("../utils/helpers")

const baseDevConfig = {
  mode: "development",
  devtool: "cheap-module-source-map"
}

const webpackDevConfig = () => {
  const config = {
    ...baseDevConfig,
    ...(runningWebpackDevServer && { devServer: webpackDevServerConfig() })
  }

  const devServerConfig = webpackDevServerConfig()
  if (runningWebpackDevServer && devServerConfig.hot && moduleExists("@pmmmwh/react-refresh-webpack-plugin")) {
    const ReactRefreshWebpackPlugin = require("@pmmmwh/react-refresh-webpack-plugin")
    config.plugins = [...(config.plugins || []), new ReactRefreshWebpackPlugin()]
  }

  return config
}

const rspackDevConfig = () => {
  const devServerConfig = webpackDevServerConfig()
  const config = {
    ...baseDevConfig,
    devServer: {
      ...devServerConfig,
      devMiddleware: {
        ...devServerConfig.devMiddleware,
        writeToDisk: (filePath) => !filePath.includes(".hot-update.")
      }
    }
  }

  if (runningWebpackDevServer && devServerConfig.hot && moduleExists("@rspack/plugin-react-refresh")) {
    const ReactRefreshPlugin = require("@rspack/plugin-react-refresh")
    config.plugins = [...(config.plugins || []), new ReactRefreshPlugin()]
  }

  return config
}

const bundlerConfig =
  config.bundler === "rspack" ? rspackDevConfig() : webpackDevConfig()

module.exports = merge(baseConfig, bundlerConfig)
