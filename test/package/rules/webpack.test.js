const rules = require("../../../package/rules/webpack")

jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  const moduleExists = () => false
  return {
    ...original,
    moduleExists
  }
})

describe("index", () => {
  test("rule tests are regexes or oneOf arrays", () => {
    rules.forEach((rule) => {
      // Rules can either have a direct test property or use oneOf
      if (rule.oneOf) {
        expect(Array.isArray(rule.oneOf)).toBe(true)
        // Check that oneOf rules are valid
        rule.oneOf.forEach((subRule) => {
          const hasTest = subRule.test instanceof RegExp
          const hasResourceQuery = subRule.resourceQuery instanceof RegExp
          expect(hasTest || hasResourceQuery).toBe(true)
        })
      } else {
        expect(rule.test instanceof RegExp).toBe(true)
      }
    })
  })
})
