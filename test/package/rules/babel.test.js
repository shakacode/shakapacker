const {
  pathToAppJavascript,
  pathToNodeModules,
  pathToNodeModulesIncluded,
  createTestCompiler,
  createTrackLoader
} = require("../../helpers")
// Mock config before importing babel rule
jest.mock("../../../package/config", () => {
  const original = jest.requireActual("../../../package/config")
  return {
    ...original,
    javascript_transpiler: "babel", // Force babel for this test
    additional_paths: [...original.additional_paths, "node_modules/included"]
  }
})

const babelConfig = require("../../../package/rules/babel")
const shakapackerBabelPreset = require("../../../package/babel/preset")
const shakapackerManifest = require("../../../package.json")
const shakapackerWebpackManifest = require("../../../packages/shakapacker-webpack/package.json")

const createBabelApi = (envName, version) => ({
  version,
  env: jest.fn((name) => (name ? name === envName : envName))
})

const presetEnvOptions = (config) =>
  config.presets.find(
    (preset) => Array.isArray(preset) && preset[0] === "@babel/preset-env"
  )[1]

const loadBabelRuleWithPackageMajors = (packageMajors) => {
  jest.resetModules()
  jest.doMock("../../../package/config", () => ({
    javascript_transpiler: "babel"
  }))
  jest.doMock("../../../package/env", () => ({
    isProduction: false
  }))
  jest.doMock("../../../package/rules/jscommon", () => ({}))
  jest.doMock("../../../package/utils/helpers", () => ({
    loaderMatches: (_configLoader, _loaderToCheck, ruleFactory) =>
      ruleFactory(),
    packageMajorVersion: (packageName) => packageMajors[packageName]
  }))

  return require("../../../package/rules/babel")
}

const loadBabelRuleWithMissingBabelCore = () => {
  jest.resetModules()
  jest.doMock("../../../package/config", () => ({
    javascript_transpiler: "babel"
  }))
  jest.doMock("../../../package/env", () => ({
    isProduction: false
  }))
  jest.doMock("../../../package/rules/jscommon", () => ({}))
  jest.doMock("../../../package/utils/errorHelpers", () => ({
    isModuleNotFoundError: (error) => error?.code === "MODULE_NOT_FOUND"
  }))
  jest.doMock("../../../package/utils/helpers", () => ({
    loaderMatches: (_configLoader, _loaderToCheck, ruleFactory) =>
      ruleFactory(),
    packageMajorVersion: (packageName) => {
      if (packageName === "@babel/core") {
        const error = new Error("Cannot find module '@babel/core/package.json'")
        error.code = "MODULE_NOT_FOUND"
        throw error
      }

      return 10
    }
  }))

  return require("../../../package/rules/babel")
}

// Skip tests if babel config is not available (not the active transpiler)
if (!babelConfig) {
  // eslint-disable-next-line jest/no-disabled-tests
  describe.skip("babel - skipped", () => {
    test.todo("skipped because babel is not the active transpiler")
  })
} else {
  const createWebpackConfig = (file, use) => ({
    entry: { file },
    module: {
      rules: [
        {
          ...babelConfig,
          use
        }
      ]
    },
    output: {
      path: "/",
      filename: "scripts-bundled.js"
    }
  })

  describe("babel", () => {
    // Mock validateBabelDependencies to avoid actual dependency checking in tests
    beforeAll(() => {
      jest.mock("../../../package/utils/helpers", () => {
        const original = jest.requireActual("../../../package/utils/helpers")
        return {
          ...original,
          validateBabelDependencies: jest.fn() // Mock to do nothing
        }
      })
    })

    afterAll(() => {
      jest.unmock("../../../package/utils/helpers")
    })

    test("process source path", async () => {
      const normalPath = `${pathToAppJavascript}/a.js`
      const [tracked, loader] = createTrackLoader()
      const compiler = createTestCompiler(
        createWebpackConfig(normalPath, loader)
      )
      await compiler.run()
      expect(tracked[normalPath]).toBeTruthy()
    })

    test("exclude node_modules", async () => {
      const ignored = `${pathToNodeModules}/a.js`
      const [tracked, loader] = createTrackLoader()
      const compiler = createTestCompiler(createWebpackConfig(ignored, loader))
      await compiler.run()
      expect(tracked[ignored]).toBeUndefined()
    })

    test("explicitly included node_modules should be transpiled", async () => {
      const included = `${pathToNodeModulesIncluded}/a.js`
      const [tracked, loader] = createTrackLoader()
      const compiler = createTestCompiler(createWebpackConfig(included, loader))
      await compiler.run()
      expect(tracked[included]).toBeTruthy()
    })

    test("explicitly included .cjs files should be transpiled", async () => {
      const included = `${pathToNodeModulesIncluded}/a.cjs`
      const [tracked, loader] = createTrackLoader()
      const compiler = createTestCompiler(createWebpackConfig(included, loader))
      await compiler.run()
      expect(tracked[included]).toBeTruthy()
    })
  })
} // end of else block for babelConfig check

describe("babel loader compatibility", () => {
  afterEach(() => {
    jest.dontMock("../../../package/config")
    jest.dontMock("../../../package/env")
    jest.dontMock("../../../package/rules/jscommon")
    jest.dontMock("../../../package/utils/helpers")
    jest.resetModules()
  })

  test("rejects Babel 8 with babel-loader older than 10", () => {
    expect(() =>
      loadBabelRuleWithPackageMajors({
        "@babel/core": 8,
        "babel-loader": 9
      })
    ).toThrow(/Babel 8 requires babel-loader 10 or newer/)
  })

  test("allows Babel 8 with babel-loader 10", () => {
    expect(
      loadBabelRuleWithPackageMajors({
        "@babel/core": 8,
        "babel-loader": 10
      }).use[0].loader
    ).toContain("babel-loader")
  })

  test("raises an actionable error when @babel/core is missing", () => {
    expect(() => loadBabelRuleWithMissingBabelCore()).toThrow(
      /@babel\/core package is not installed/
    )
  })
})

describe("babel preset", () => {
  test("keeps Babel 7 preset-env and transform-runtime options", () => {
    const config = shakapackerBabelPreset(
      createBabelApi("production", "7.29.0")
    )

    expect(presetEnvOptions(config)).toMatchObject({
      useBuiltIns: "entry",
      corejs: "3.8",
      modules: "auto",
      bugfixes: true,
      exclude: ["transform-typeof-symbol"]
    })
    expect(config.plugins).toContainEqual([
      "@babel/plugin-transform-runtime",
      { helpers: false }
    ])
  })

  test("omits options Babel 8 removed", () => {
    const config = shakapackerBabelPreset(createBabelApi("production", "8.0.1"))
    const options = presetEnvOptions(config)

    expect(options).toMatchObject({
      modules: "auto",
      exclude: ["transform-typeof-symbol"]
    })
    expect(options).not.toHaveProperty("useBuiltIns")
    expect(options).not.toHaveProperty("corejs")
    expect(options).not.toHaveProperty("bugfixes")
    expect(config.plugins).toContain("@babel/plugin-transform-runtime")
    expect(config.plugins).not.toContainEqual([
      "@babel/plugin-transform-runtime",
      { helpers: false }
    ])
  })

  test("allows Babel 8 peers without changing Babel 7 development pins", () => {
    expect(shakapackerManifest.devDependencies["@babel/core"]).toMatch(/^7\./)
    expect(shakapackerManifest.peerDependencies).toMatchObject({
      "@babel/core": "^7.17.9 || ^8.0.0",
      "@babel/plugin-transform-runtime": "^7.17.0 || ^8.0.0",
      "@babel/preset-env": "^7.16.11 || ^8.0.0",
      "@babel/runtime": "^7.17.9 || ^8.0.0"
    })
    expect(shakapackerWebpackManifest.peerDependencies["@babel/core"]).toBe(
      "^7.17.9 || ^8.0.0"
    )
  })
})
