"use strict";
/**
 * Test environment configuration for webpack and rspack bundlers
 * @module environments/test
 */
Object.defineProperty(exports, "__esModule", { value: true });
const { merge } = require("webpack-merge");
const config = require("../config");
const baseConfig = require("./base");
/**
 * Generate rspack-specific test configuration
 * @returns Rspack configuration optimized for testing
 */
const rspackTestConfig = () => ({
    mode: "development",
    devtool: "cheap-module-source-map",
    // Disable file watching in test mode
    watchOptions: {
        ignored: /node_modules/
    }
});
/**
 * Generate webpack-specific test configuration
 * @returns Webpack configuration for testing (uses default settings)
 */
const webpackTestConfig = () => ({});
const bundlerConfig = config.assets_bundler === "rspack" ? rspackTestConfig() : webpackTestConfig();
module.exports = merge(baseConfig, bundlerConfig);
