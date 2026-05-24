const { execFileSync } = require("child_process")
const { mkdtempSync, readFileSync, rmSync } = require("fs")
const { join } = require("path")
const { tmpdir } = require("os")

describe("rspack/index types", () => {
  test("declaration emit includes the lazy rspack export properties", () => {
    const outDir = mkdtempSync(join(tmpdir(), "shakapacker-rspack-types-"))

    try {
      execFileSync(
        "./node_modules/.bin/tsc",
        [
          "--emitDeclarationOnly",
          "--declaration",
          "--declarationMap",
          "false",
          "--outDir",
          outDir
        ],
        { stdio: ["pipe", "pipe", "inherit"] }
      )

      const declaration = readFileSync(
        join(outDir, "rspack", "index.d.ts"),
        "utf8"
      )

      // Verify lazy exports are present with their real types (not `any`)
      // on the CommonJS export object.
      expect(declaration).toMatch(
        /readonly baseConfig: RspackConfigWithDevServer/
      )
      expect(declaration).toMatch(/readonly rules: RuleSetRule\[\]/)
      expect(declaration).toMatch(
        /declare const rspackExports: RspackExports/
      )
      expect(declaration).toContain("export = rspackExports")
      expect(declaration).toContain("env")
      expect(declaration).toContain("moduleExists")
    } finally {
      rmSync(outDir, { recursive: true, force: true })
    }
  }, 60000)
})
