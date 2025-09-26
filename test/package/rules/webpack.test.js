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
  test("rule tests are regexes", () => {
    rules.forEach((rule) => expect(rule.test instanceof RegExp).toBe(true))
  })
})
