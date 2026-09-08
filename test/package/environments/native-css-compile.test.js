// Compiles the rule getStyleRule actually emits, with a real webpack, so that
// parser/generator/experiments wiring is verified against the bundler rather
// than only against a mocked config object.

const fs = require("fs")
const os = require("os")
const path = require("path")
const webpack = require("webpack")

const { chdirTestApp } = require("../../helpers")

const rootPath = process.cwd()
chdirTestApp()

let fixtureDir

const loadNativeCssRules = () => {
  jest.resetModules()

  jest.doMock("../../../package/utils/helpers", () => {
    const original = jest.requireActual("../../../package/utils/helpers")
    return {
      ...original,
      moduleExists: (moduleName) => moduleName !== "css-loader"
    }
  })

  const { getStyleRule } = require("../../../package/utils/getStyleRule")
  return [getStyleRule(/\.(css)$/i)]
}

const compile = (config) =>
  new Promise((resolve, reject) => {
    webpack(config, (err, stats) => {
      if (err) return reject(err)
      if (stats.hasErrors()) {
        return reject(new Error(stats.toString({ preset: "errors-only" })))
      }
      return resolve(stats)
    })
  })

describe("built-in CSS compilation", () => {
  beforeAll(() => {
    fixtureDir = fs.mkdtempSync(
      path.join(os.tmpdir(), "shakapacker-native-css-")
    )
    fs.writeFileSync(
      path.join(fixtureDir, "plain.css"),
      "body { color: blue; }\n"
    )
    fs.writeFileSync(
      path.join(fixtureDir, "styles.module.css"),
      ".my-button { color: red; }\n"
    )
    fs.writeFileSync(
      path.join(fixtureDir, "index.js"),
      'import "./plain.css"\nimport * as styles from "./styles.module.css"\nconsole.log(styles.myButton)\n'
    )
  })

  afterAll(() => {
    if (fixtureDir) fs.rmSync(fixtureDir, { recursive: true, force: true })
    process.chdir(rootPath)
  })

  test("emits a stylesheet and camelCase named exports", async () => {
    const outputDir = path.join(fixtureDir, "out")

    const stats = await compile({
      mode: "development",
      devtool: false,
      entry: path.join(fixtureDir, "index.js"),
      // Mirrors what base.ts sets on the built-in CSS path.
      experiments: { css: true },
      output: {
        path: outputDir,
        filename: "js/[name].js",
        cssFilename: "css/[name].css"
      },
      module: { rules: loadNativeCssRules() }
    })

    const assets = stats.toJson({ assets: true }).assets.map((a) => a.name)
    expect(assets).toContain("css/main.css")

    const emittedCss = fs.readFileSync(
      path.join(outputDir, "css", "main.css"),
      "utf8"
    )
    // Plain CSS stays global; the .module.css class is scoped and camelCased.
    expect(emittedCss).toContain("body { color: blue; }")
    expect(emittedCss).toMatch(/\.[\w-]*myButton\b/)
    expect(emittedCss).not.toContain(".my-button")

    const emittedJs = fs.readFileSync(
      path.join(outputDir, "js", "main.js"),
      "utf8"
    )
    expect(emittedJs).toContain("myButton")
  }, 30000)
})
