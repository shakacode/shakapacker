/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

const rules = {
  raw: require('./raw'),
  file: require('./file'),
  css: require('./css'),
  sass: require('./sass'),
  // TODO: Makes this switchable
  // babel: require('./babel'),
  swc: require('./swc'),
  erb: require('./erb'),
  coffee: require('./coffee'),
  less: require('./less'),
  stylus: require('./stylus')
}

module.exports = Object.keys(rules)
  .filter((key) => !!rules[key])
  .flatMap((key) => rules[key])
