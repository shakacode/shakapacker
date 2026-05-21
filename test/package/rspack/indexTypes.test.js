const { execFileSync } = require("child_process")
const { mkdtempSync, readFileSync, rmSync } = require("fs")
const { join } = require("path")
const { tmpdir } = require("os")

describe("rspack/index types", () => {
  test("declaration emit includes the lazy baseConfig export", () => {
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

      // Verify lazy exports are present with their real types (not `any`),
      // proving the placeholder `const x = undefined as unknown as T` pattern
      // survives the compile and the named exports include baseConfig/rules.
      expect(declaration).toMatch(
        /declare const baseConfig: RspackConfigWithDevServer/
      )
      expect(declaration).toMatch(/declare const rules: RuleSetRule\[\]/)
      expect(declaration).toMatch(/export \{[^}]*\bbaseConfig\b[^}]*\}/)
      expect(declaration).toMatch(/export \{[^}]*\brules\b[^}]*\}/)
      expect(declaration).toContain("env")
      expect(declaration).toContain("moduleExists")
    } finally {
      rmSync(outDir, { recursive: true, force: true })
    }
  })
})
