"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const { merge } = require("webpack-merge");
const config = require("../config");
const baseConfig = require("./base");
const webpackDevServerConfig = require("../webpackDevServerConfig");
const { runningWebpackDevServer } = require("../env");
const { moduleExists } = require("../utils/helpers");
const baseDevConfig = {
    mode: "development",
    devtool: "cheap-module-source-map"
};
const webpackDevConfig = () => {
    const webpackConfig = {
        ...baseDevConfig,
        ...(runningWebpackDevServer && { devServer: webpackDevServerConfig() })
    };
    const devServerConfig = webpackDevServerConfig();
    if (runningWebpackDevServer &&
        devServerConfig.hot &&
        moduleExists("@pmmmwh/react-refresh-webpack-plugin")) {
        // eslint-disable-next-line global-require
        const ReactRefreshWebpackPlugin = require("@pmmmwh/react-refresh-webpack-plugin");
        webpackConfig.plugins = [
            ...(webpackConfig.plugins || []),
            new ReactRefreshWebpackPlugin()
        ];
    }
    return webpackConfig;
};
const rspackDevConfig = () => {
    const devServerConfig = webpackDevServerConfig();
    const rspackConfig = {
        ...baseDevConfig,
        devServer: {
            ...devServerConfig,
            devMiddleware: {
                ...devServerConfig.devMiddleware,
                writeToDisk: (filePath) => !filePath.includes(".hot-update.")
            }
        }
    };
    if (runningWebpackDevServer &&
        devServerConfig.hot &&
        moduleExists("@rspack/plugin-react-refresh")) {
        // eslint-disable-next-line global-require
        const ReactRefreshPlugin = require("@rspack/plugin-react-refresh");
        rspackConfig.plugins = [
            ...(rspackConfig.plugins || []),
            new ReactRefreshPlugin()
        ];
    }
    return rspackConfig;
};
const bundlerConfig = config.assets_bundler === "rspack" ? rspackDevConfig() : webpackDevConfig();
module.exports = merge(baseConfig, bundlerConfig);
