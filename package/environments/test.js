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
 * Shared test configuration for both webpack and rspack
 * Ensures consistent test behavior across bundlers
 */
const sharedTestConfig = {
    mode: "development",
    devtool: "cheap-module-source-map",
    // Disable file watching in test mode
    watchOptions: {
        ignored: /node_modules/
    }
};
/**
 * Generate rspack-specific test configuration
 * @returns Rspack configuration optimized for testing
 */
const rspackTestConfig = () => ({
    ...sharedTestConfig
    // Add any rspack-specific overrides here if needed
});
/**
 * Generate webpack-specific test configuration
 * @returns Webpack configuration for testing with same settings as rspack
 */
const webpackTestConfig = () => ({
    ...sharedTestConfig
    // Add any webpack-specific overrides here if needed
});
const bundlerConfig = config.assets_bundler === "rspack" ? rspackTestConfig() : webpackTestConfig();
module.exports = merge(baseConfig, bundlerConfig);

