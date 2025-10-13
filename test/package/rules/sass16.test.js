const sass = require("../../../package/rules/sass").default

jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  const canProcess = (rule, fn) => fn("This path was mocked")
  const packageMajorVersion = () => 16
  return {
    ...original,
    canProcess,
    packageMajorVersion
  }
})

jest.mock("../../../package/utils/inliningCss", () => true)

describe("sass rule", () => {
  test("contains loadPaths as the sassOptions key if sass-loader is v16 or later", () => {
    expect(typeof sass.use[3].options.sassOptions.includePaths).toBe(
      "undefined"
    )
    expect(typeof sass.use[3].options.sassOptions.loadPaths).toBe("object")
  })
})
