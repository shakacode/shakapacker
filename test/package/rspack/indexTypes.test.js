const { execFileSync } = require("child_process")
const {
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync
} = require("fs")
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
      // on the named export surface.
      expect(declaration).toMatch(
        /declare const baseConfig: RspackConfigWithDevServer/
      )
      expect(declaration).toMatch(/declare const rules: RuleSetRule\[\]/)
      expect(declaration).toContain("generateRspackConfig")
      expect(declaration).toContain("env")
      expect(declaration).toContain("moduleExists")
    } finally {
      rmSync(outDir, { recursive: true, force: true })
    }
  }, 60000)

  test("compiled rspack entry supports native ESM named imports", () => {
    const rootDir = mkdtempSync(join(tmpdir(), "shakapacker-rspack-esm-"))
    const outDir = join(rootDir, "package")

    try {
      execFileSync("./node_modules/.bin/tsc", ["--outDir", outDir], {
        stdio: ["pipe", "pipe", "inherit"]
      })
      symlinkSync(
        join(process.cwd(), "node_modules"),
        join(rootDir, "node_modules")
      )
      symlinkSync(join(process.cwd(), "lib"), join(rootDir, "lib"))

      const consumerPath = join(rootDir, "rspack-esm-consumer.mjs")
      writeFileSync(
        consumerPath,
        [
          'import { generateRspackConfig } from "./package/rspack/index.js"',
          'if (typeof generateRspackConfig !== "function") {',
          '  throw new Error("generateRspackConfig was not imported")',
          "}",
          'console.log("rspack ESM named imports ok")'
        ].join("\n")
      )

      const output = execFileSync(process.execPath, [consumerPath], {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "inherit"]
      })

      expect(output).toContain("rspack ESM named imports ok")
    } finally {
      rmSync(rootDir, { recursive: true, force: true })
    }
  }, 60000)

  test("compiled rspack lazy exports work from native ESM default import", () => {
    // Native ESM named imports only cover statically detected CommonJS exports;
    // lazy accessor exports stay available through the default/CommonJS namespace.
    const rootDir = mkdtempSync(join(tmpdir(), "shakapacker-rspack-esm-"))
    const outDir = join(rootDir, "package")

    try {
      execFileSync("./node_modules/.bin/tsc", ["--outDir", outDir], {
        stdio: ["pipe", "pipe", "inherit"]
      })
      symlinkSync(
        join(process.cwd(), "node_modules"),
        join(rootDir, "node_modules")
      )
      symlinkSync(join(process.cwd(), "lib"), join(rootDir, "lib"))

      const consumerPath = join(rootDir, "rspack-esm-lazy-consumer.mjs")
      writeFileSync(
        consumerPath,
        [
          'import rspack from "./package/rspack/index.js"',
          "const { baseConfig, rules } = rspack",
          'if (baseConfig === null || typeof baseConfig !== "object") {',
          '  throw new Error("baseConfig was not imported")',
          "}",
          "if (!Array.isArray(rules)) {",
          '  throw new Error("rules was not imported")',
          "}",
          'console.log("rspack ESM lazy exports ok")'
        ].join("\n")
      )

      const output = execFileSync(process.execPath, [consumerPath], {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "inherit"]
      })

      expect(output).toContain("rspack ESM lazy exports ok")
    } finally {
      rmSync(rootDir, { recursive: true, force: true })
    }
  }, 60000)
})
