const raw = require("../../../package/rules/raw")
const config = require("../../../package/config")

describe("raw", () => {
  test("rspack config uses resourceQuery", () => {
    if (config.assets_bundler === "rspack") {
      expect(raw.resourceQuery).toEqual(/raw/)
      expect(raw.type).toBe("asset/source")
    }
  })

  test("webpack config supports ?raw query and .html fallback", () => {
    if (config.assets_bundler !== "rspack") {
      expect(raw.oneOf).toHaveLength(2)
      // First rule: any file with ?raw
      expect(raw.oneOf[0].resourceQuery).toEqual(/raw/)
      expect(raw.oneOf[0].type).toBe("asset/source")
      // Second rule: .html files without query
      expect(raw.oneOf[1].test.test(".html")).toBe(true)
      expect(raw.oneOf[1].exclude.test(".js")).toBe(true)
      expect(raw.oneOf[1].type).toBe("asset/source")
    }
  })
})
