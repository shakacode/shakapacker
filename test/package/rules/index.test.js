const rules = require('../index')

describe('index', () => {
  test('rule tests are regexes', () => {
    rules.forEach(rule => expect(rule.test instanceof RegExp).toBe(true))
  })
})
