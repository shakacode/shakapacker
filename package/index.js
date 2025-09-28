"use strict";
/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
const webpackMerge = require("webpack-merge");
const path_1 = require("path");
const fs_1 = require("fs");
const config = require("./config");
const baseConfig = require("./environments/base");
const devServer = require("./dev_server");
const env = require("./env");
const { moduleExists, canProcess } = require("./utils/helpers");
const inliningCss = require("./utils/inliningCss");
const rulesPath = (0, path_1.resolve)(__dirname, "rules", `${config.assets_bundler}.js`);
const rules = require(rulesPath);
const generateWebpackConfig = (extraConfig = {}, ...extraArgs) => {
    if (extraArgs.length > 0) {
        throw new Error("Only one extra config may be passed here - use webpack-merge to merge configs before passing them to Shakapacker");
    }
    const { nodeEnv } = env;
    const path = (0, path_1.resolve)(__dirname, "environments", `${nodeEnv}.js`);
    const environmentConfig = (0, fs_1.existsSync)(path) ? require(path) : baseConfig;
    return webpackMerge.merge({}, environmentConfig, extraConfig);
};
module.exports = {
    config, // shakapacker.yml
    devServer,
    generateWebpackConfig,
    baseConfig,
    env,
    rules,
    moduleExists,
    canProcess,
    inliningCss,
    ...webpackMerge
};
