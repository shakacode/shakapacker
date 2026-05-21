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
        { stdio: "pipe" }
      )

      const declaration = readFileSync(
        join(outDir, "rspack", "index.d.ts"),
        "utf8"
      )

      expect(declaration).toContain("baseConfig")
      expect(declaration).toContain(
        "baseConfig, env, rules, moduleExists"
      )
    } finally {
      rmSync(outDir, { recursive: true, force: true })
    }
  })
})
