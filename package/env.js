"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
const js_yaml_1 = require("js-yaml");
const fs_1 = require("fs");
const defaultConfigPath_1 = __importDefault(require("./utils/defaultConfigPath"));
const configPath_1 = __importDefault(require("./utils/configPath"));
const { isFileNotFoundError } = require("./utils/errorHelpers");
const NODE_ENVIRONMENTS = ["development", "production", "test"];
const DEFAULT = "production";
const initialRailsEnv = process.env.RAILS_ENV;
const rawNodeEnv = process.env.NODE_ENV;
const nodeEnv = rawNodeEnv && NODE_ENVIRONMENTS.includes(rawNodeEnv) ? rawNodeEnv : DEFAULT;
const isProduction = nodeEnv === "production";
const isDevelopment = nodeEnv === "development";
let config;
try {
    config = (0, js_yaml_1.load)((0, fs_1.readFileSync)(configPath_1.default, "utf8"));
}
catch (error) {
    if (isFileNotFoundError(error)) {
        // File not found, use default configuration
        try {
            config = (0, js_yaml_1.load)((0, fs_1.readFileSync)(defaultConfigPath_1.default, "utf8"));
        }
        catch (defaultError) {
            throw new Error(`Failed to load configuration: neither user config nor default config found`);
        }
    }
    else {
        throw error;
    }
}
const availableEnvironments = Object.keys(config).join("|");
const regex = new RegExp(`^(${availableEnvironments})$`, "g");
const runningWebpackDevServer = process.env.WEBPACK_SERVE === "true";
const validatedRailsEnv = initialRailsEnv && initialRailsEnv.match(regex) ? initialRailsEnv : DEFAULT;
if (initialRailsEnv && validatedRailsEnv !== initialRailsEnv) {
    /* eslint no-console:0 */
    console.warn(`Warning: '${initialRailsEnv}' environment not found in the configuration. Using '${DEFAULT}' configuration as a fallback.`);
}
module.exports = {
    railsEnv: validatedRailsEnv,
    nodeEnv,
    isProduction,
    isDevelopment,
    runningWebpackDevServer
};
