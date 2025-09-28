const { packageMajorVersion, validateBabelDependencies, moduleExists } = require("../../package/utils/helpers")

describe("packageMajorVersion", () => {
  test("should find that sass-loader is v16", () => {
    expect(packageMajorVersion("sass-loader")).toBe("16")
  })

  test("should find that nonexistent is v12", () => {
    expect(packageMajorVersion("nonexistent")).toBe("12")
  })
})

describe("validateBabelDependencies", () => {
  // Mock moduleExists to control what packages are "installed"
  const originalModuleExists = moduleExists
  
  beforeEach(() => {
    // Reset the mock before each test
    jest.resetModules()
  })

  test("should not throw when Babel core packages are present", () => {
    // Mock that both core packages exist
    const helpers = require("../../package/utils/helpers")
    helpers.moduleExists = jest.fn((pkg) => {
      return pkg === "@babel/core" || pkg === "babel-loader"
    })
    
    expect(() => helpers.validateBabelDependencies()).not.toThrow()
  })

  test("should throw when @babel/core is missing", () => {
    const helpers = require("../../package/utils/helpers")
    helpers.moduleExists = jest.fn((pkg) => {
      return pkg === "babel-loader" // Only babel-loader exists
    })
    
    expect(() => helpers.validateBabelDependencies()).toThrow(/Babel is configured but core packages are missing: @babel\/core/)
  })

  test("should throw when babel-loader is missing", () => {
    const helpers = require("../../package/utils/helpers")
    helpers.moduleExists = jest.fn((pkg) => {
      return pkg === "@babel/core" // Only @babel/core exists
    })
    
    expect(() => helpers.validateBabelDependencies()).toThrow(/Babel is configured but core packages are missing: babel-loader/)
  })

  test("should throw when both core packages are missing", () => {
    const helpers = require("../../package/utils/helpers")
    helpers.moduleExists = jest.fn(() => false) // No packages exist
    
    expect(() => helpers.validateBabelDependencies()).toThrow(/Babel is configured but core packages are missing: @babel\/core, babel-loader/)
  })

  test("should suggest optional packages when they're missing", () => {
    const helpers = require("../../package/utils/helpers")
    helpers.moduleExists = jest.fn((pkg) => {
      // Core packages exist, but optional ones don't
      return pkg === "@babel/core" || pkg === "babel-loader"
    })
    
    // Should not throw since core packages are present
    expect(() => helpers.validateBabelDependencies()).not.toThrow()
  })

  test("should provide migration tip to SWC in error message", () => {
    const helpers = require("../../package/utils/helpers")
    helpers.moduleExists = jest.fn(() => false) // No packages exist
    
    expect(() => helpers.validateBabelDependencies()).toThrow(/Consider migrating to SWC for 20x faster compilation/)
  })
})
