const sass = require("../../../package/rules/sass")

jest.mock("../../../package/utils/helpers", () => {
  const original = jest.requireActual("../../../package/utils/helpers")
  const canProcess = (rule, fn) => {
    return fn("This path was mocked")
  }
  const packageMajorVersion = () => "15"
  return {
    ...original,
    canProcess,
    packageMajorVersion
  }
})

jest.mock("../../../package/utils/inliningCss", () => true)

describe("sass rule", () => {
  test("contains loadPaths as the sassOptions key if sass-loader is v15 or earlier", () => {
    expect(typeof sass.use[3].options.sassOptions.includePaths).toBe("object")
    expect(typeof sass.use[3].options.sassOptions.loadPaths).toBe("undefined")
  })
})
