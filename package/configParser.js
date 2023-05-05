const { load } = require('js-yaml')
const { readFileSync } = require('fs')

const parseConfig = (configPath) => load(readFileSync(configPath), 'utf8')

module.exports = parseConfig