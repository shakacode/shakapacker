"use strict";
const path_1 = require("path");
const configPath = process.env.SHAKAPACKER_CONFIG || (0, path_1.resolve)("config", "shakapacker.yml");
module.exports = configPath;
