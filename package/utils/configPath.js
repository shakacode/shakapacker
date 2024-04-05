const { resolve } = require("path")

module.exports =
  process.env.SHAKAPACKER_CONFIG || resolve("config", "shakapacker.yml")
