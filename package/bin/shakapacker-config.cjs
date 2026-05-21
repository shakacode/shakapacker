#!/usr/bin/env node

const { run } = require("../configExporter")

run(process.argv.slice(2))
  .then((exitCode) => process.exit(exitCode))
  .catch((error) => {
    console.error(error.message)
    process.exit(1)
  })
