"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const path_1 = require("path");
const configPath = process.env.SHAKAPACKER_CONFIG || (0, path_1.resolve)("config", "shakapacker.yml");
exports.default = configPath;
