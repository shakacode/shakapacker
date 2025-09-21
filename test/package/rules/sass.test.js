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
  test("contains includePaths as the sassOptions key if sass-loader is v15 or earlier", () => {
    expect(sass).not.toBeNull()
    expect(sass.use).toBeDefined()
    // sass-loader is the first loader in the use array
    const sassLoader = sass.use[0]
    expect(sassLoader).toBeDefined()
    expect(typeof sassLoader.options.sassOptions.includePaths).toBe("object")
    expect(typeof sassLoader.options.sassOptions.loadPaths).toBe("undefined")
  })
})
