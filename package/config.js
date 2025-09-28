"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
const path_1 = require("path");
const js_yaml_1 = require("js-yaml");
const fs_1 = require("fs");
const webpack_merge_1 = require("webpack-merge");
const { ensureTrailingSlash } = require("./utils/helpers");
const { railsEnv } = require("./env");
const configPath_1 = __importDefault(require("./utils/configPath"));
const defaultConfigPath_1 = __importDefault(require("./utils/defaultConfigPath"));
const { isValidYamlConfig, createConfigValidationError, isPartialConfig } = require("./utils/typeGuards");
const { isFileNotFoundError, createFileOperationError } = require("./utils/errorHelpers");
const getDefaultConfig = () => {
    try {
        const fileContent = (0, fs_1.readFileSync)(defaultConfigPath_1.default, "utf8");
        const defaultConfig = (0, js_yaml_1.load)(fileContent);
        if (!isValidYamlConfig(defaultConfig)) {
            throw createConfigValidationError(defaultConfigPath_1.default, railsEnv, "Invalid YAML structure");
        }
        return defaultConfig[railsEnv] || defaultConfig.production || {};
    }
    catch (error) {
        if (isFileNotFoundError(error)) {
            throw createFileOperationError('read', defaultConfigPath_1.default, 'Default configuration not found');
        }
        throw error;
    }
};
const defaults = getDefaultConfig();
let config;
if ((0, fs_1.existsSync)(configPath_1.default)) {
    try {
        const fileContent = (0, fs_1.readFileSync)(configPath_1.default, "utf8");
        const appYmlObject = (0, js_yaml_1.load)(fileContent);
        if (!isValidYamlConfig(appYmlObject)) {
            throw createConfigValidationError(configPath_1.default, railsEnv, "Invalid YAML structure");
        }
        const envAppConfig = appYmlObject[railsEnv];
        if (!envAppConfig) {
            /* eslint no-console:0 */
            console.warn(`Warning: ${railsEnv} key not found in the configuration file. Using production configuration as a fallback.`);
        }
        // Merge returns the merged type
        const mergedConfig = (0, webpack_merge_1.merge)(defaults, envAppConfig || {});
        // Validate merged config before type assertion
        if (!isPartialConfig(mergedConfig)) {
            throw createConfigValidationError(configPath_1.default, railsEnv, "Invalid merged configuration");
        }
        config = mergedConfig;
    }
    catch (error) {
        if (isFileNotFoundError(error)) {
            // File not found is OK, use defaults
            if (!isPartialConfig(defaults)) {
                throw createConfigValidationError(defaultConfigPath_1.default, railsEnv, "Invalid default configuration");
            }
            config = defaults;
        }
        else {
            throw error;
        }
    }
}
else {
    // No user config, use defaults
    if (!isPartialConfig(defaults)) {
        throw createConfigValidationError(defaultConfigPath_1.default, railsEnv, "Invalid default configuration");
    }
    config = defaults;
}
config.outputPath = (0, path_1.resolve)(config.public_root_path, config.public_output_path);
// Ensure that the publicPath includes our asset host so dynamic imports
// (code-splitting chunks and static assets) load from the CDN instead of a relative path.
const getPublicPath = () => {
    const rootUrl = ensureTrailingSlash(process.env.SHAKAPACKER_ASSET_HOST || "/");
    return `${rootUrl}${config.public_output_path}/`;
};
config.publicPath = getPublicPath();
config.publicPathWithoutCDN = `/${config.public_output_path}/`;
if (config.manifest_path) {
    config.manifestPath = (0, path_1.resolve)(config.manifest_path);
}
else {
    config.manifestPath = (0, path_1.resolve)(config.outputPath, "manifest.json");
}
// Ensure no duplicate hash functions exist in the returned config object
if (config.integrity?.hash_functions) {
    config.integrity.hash_functions = [...new Set(config.integrity.hash_functions)];
}
// Allow ENV variable to override assets_bundler
if (process.env.SHAKAPACKER_ASSETS_BUNDLER) {
    config.assets_bundler = process.env.SHAKAPACKER_ASSETS_BUNDLER;
}
// Define clear defaults
// SWC is now the default transpiler for both webpack and rspack
const DEFAULT_JAVASCRIPT_TRANSPILER = "swc"
// Backward compatibility: Add webpack_loader property that maps to javascript_transpiler
// Show deprecation warning if webpack_loader is used
const webpackLoader = config.webpack_loader;
if (webpackLoader && !config.javascript_transpiler) {
    console.warn("⚠️  DEPRECATION WARNING: The 'webpack_loader' configuration option is deprecated. Please use 'javascript_transpiler' instead as it better reflects its purpose of configuring JavaScript transpilation regardless of the bundler used.");
    config.javascript_transpiler = webpackLoader;
}
else if (!config.javascript_transpiler) {
    config.javascript_transpiler =
        webpackLoader || DEFAULT_JAVASCRIPT_TRANSPILER;
}
// Ensure webpack_loader is always available for backward compatibility
const legacyConfig = config;
legacyConfig.webpack_loader = config.javascript_transpiler;
module.exports = config;
