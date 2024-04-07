function snakeToCamelCase(s) {
  return s.replace(/(_\w)/g, (match) => match[1].toUpperCase())
}

module.exports = snakeToCamelCase
