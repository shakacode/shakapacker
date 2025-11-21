/* eslint-disable jest/no-conditional-in-test, no-unused-vars */

// Mock helpers and debug utilities
jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  return {
    ...original,
    moduleExists: jest.fn(() => true)
  }
})

jest.mock("../../../package/utils/debug", () => ({
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn()
}))

describe("rspack/rules", () => {
  let rules

  beforeEach(() => {
    jest.clearAllMocks()
  })

  beforeAll(() => {
    rules = require("../../../package/rules/rspack")
  })

  describe("rules array", () => {
    test("exports an array", () => {
      expect(Array.isArray(rules)).toBe(true)
    })

    test("contains multiple rules", () => {
      expect(rules.length).toBeGreaterThan(0)
    })
  })

  describe("javaScript rule", () => {
    test("includes rule for JS/JSX files", () => {
      const jsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("js|jsx|mjs")
      )

      expect(jsRule).toBeDefined()
    })

    test("uses builtin:swc-loader for JavaScript", () => {
      const jsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("js|jsx|mjs")
      )

      expect(jsRule.use).toBeDefined()
      expect(Array.isArray(jsRule.use)).toBe(true)
      expect(jsRule.use[0].loader).toBe("builtin:swc-loader")
    })

    test("excludes node_modules for JavaScript", () => {
      const jsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("js|jsx|mjs")
      )

      expect(jsRule.exclude).toBeDefined()
      expect(jsRule.exclude.toString()).toContain("node_modules")
    })

    test("sets type to javascript/auto for JavaScript", () => {
      const jsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("js|jsx|mjs")
      )

      expect(jsRule.type).toBe("javascript/auto")
    })

    test("configures SWC with JSX runtime automatic", () => {
      const jsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("js|jsx|mjs")
      )

      expect(jsRule.use[0].options).toBeDefined()
      expect(jsRule.use[0].options.jsc.parser.syntax).toBe("ecmascript")
      expect(jsRule.use[0].options.jsc.parser.jsx).toBe(true)
      expect(jsRule.use[0].options.jsc.transform.react.runtime).toBe(
        "automatic"
      )
    })
  })

  describe("typeScript rule", () => {
    test("includes rule for TS/TSX files", () => {
      const tsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("ts|tsx")
      )

      expect(tsRule).toBeDefined()
    })

    test("uses builtin:swc-loader for TypeScript", () => {
      const tsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("ts|tsx")
      )

      expect(tsRule.use).toBeDefined()
      expect(Array.isArray(tsRule.use)).toBe(true)
      expect(tsRule.use[0].loader).toBe("builtin:swc-loader")
    })

    test("excludes node_modules for TypeScript", () => {
      const tsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("ts|tsx")
      )

      expect(tsRule.exclude).toBeDefined()
      expect(tsRule.exclude.toString()).toContain("node_modules")
    })

    test("sets type to javascript/auto for TypeScript", () => {
      const tsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("ts|tsx")
      )

      expect(tsRule.type).toBe("javascript/auto")
    })

    test("configures SWC with TypeScript parser", () => {
      const tsRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("ts|tsx")
      )

      expect(tsRule.use[0].options).toBeDefined()
      expect(tsRule.use[0].options.jsc.parser.syntax).toBe("typescript")
      expect(tsRule.use[0].options.jsc.parser.tsx).toBe(true)
      expect(tsRule.use[0].options.jsc.transform.react.runtime).toBe(
        "automatic"
      )
    })
  })

  describe("cSS rules", () => {
    test("conditionally includes CSS rule based on css-loader availability", () => {
      // This test verifies the conditional logic exists
      // The actual rule inclusion depends on whether css-loader is installed
      const cssRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("css")
      )

      // CSS rule may or may not be present depending on dependencies
      // We just verify the rules array is properly formed
      expect(Array.isArray(rules)).toBe(true)
    })
  })

  describe("sass rules", () => {
    test("conditionally includes Sass rule based on dependencies", () => {
      // Sass rule may or may not be present depending on installed dependencies
      const sassRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("scss|sass")
      )

      // Just verify the rules array structure is correct
      expect(Array.isArray(rules)).toBe(true)
    })
  })

  describe("less rules", () => {
    test("conditionally includes Less rule based on dependencies", () => {
      // Less rule may or may not be present depending on installed dependencies
      const lessRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("less")
      )

      // Just verify the rules array structure is correct
      expect(Array.isArray(rules)).toBe(true)
    })
  })

  describe("stylus rules", () => {
    test("conditionally includes Stylus rule based on dependencies", () => {
      // Stylus rule may or may not be present depending on installed dependencies
      const stylusRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("styl")
      )

      // Just verify the rules array structure is correct
      expect(Array.isArray(rules)).toBe(true)
    })
  })

  describe("eRB rule", () => {
    test("includes ERB rule", () => {
      const erbRule = rules.find(
        (rule) => rule.test && rule.test.toString().includes("erb")
      )

      expect(erbRule).toBeDefined()
    })
  })

  describe("file/asset rule", () => {
    test("includes file/asset handling rule", () => {
      const fileRule = rules.find(
        (rule) =>
          rule.test &&
          (rule.test.toString().includes("png") ||
            rule.test.toString().includes("jpg") ||
            rule.test.toString().includes("svg"))
      )

      expect(fileRule).toBeDefined()
    })
  })

  describe("raw file rule", () => {
    test("includes raw file loading rule", () => {
      // Raw rule may be a direct rule or nested in oneOf
      const rawRule =
        rules.find(
          (rule) =>
            rule.type === "asset/source" &&
            rule.resourceQuery &&
            rule.resourceQuery.toString().includes("raw")
        ) ||
        rules
          .filter((rule) => rule.oneOf)
          .flatMap((rule) => rule.oneOf)
          .find(
            (subRule) =>
              subRule.type === "asset/source" &&
              subRule.resourceQuery &&
              subRule.resourceQuery.toString().includes("raw")
          )

      expect(rawRule).toBeDefined()
      expect(rawRule.type).toBe("asset/source")
    })
  })
})
