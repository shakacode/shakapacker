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

  // The two native-ESM specs below run identical full compilations, so share a
  // single tsc build (and node_modules/lib symlinks) across them to avoid paying
  // the compile cost twice in CI. Each spec only writes and runs its own .mjs
  // consumer against the shared output.
  describe("native ESM consumers", () => {
    let sharedRootDir

    const runConsumer = (fileName, lines) => {
      const consumerPath = join(sharedRootDir, fileName)
      writeFileSync(consumerPath, lines.join("\n"))

      return execFileSync(process.execPath, [consumerPath], {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "inherit"]
      })
    }

    beforeAll(() => {
      sharedRootDir = mkdtempSync(join(tmpdir(), "shakapacker-rspack-esm-"))
      const outDir = join(sharedRootDir, "package")

      execFileSync("./node_modules/.bin/tsc", ["--outDir", outDir], {
        stdio: ["pipe", "pipe", "inherit"]
      })
      symlinkSync(
        join(process.cwd(), "node_modules"),
        join(sharedRootDir, "node_modules")
      )
      symlinkSync(join(process.cwd(), "lib"), join(sharedRootDir, "lib"))
    }, 60000)

    afterAll(() => {
      if (sharedRootDir) {
        rmSync(sharedRootDir, { recursive: true, force: true })
      }
    })

    test("compiled rspack entry supports native ESM named imports", () => {
      const output = runConsumer("rspack-esm-consumer.mjs", [
        'import { generateRspackConfig } from "./package/rspack/index.js"',
        'if (typeof generateRspackConfig !== "function") {',
        '  throw new Error("generateRspackConfig was not imported")',
        "}",
        'console.log("rspack ESM named imports ok")'
      ])

      expect(output).toContain("rspack ESM named imports ok")
    })

    test("compiled rspack lazy exports work from native ESM default import", () => {
      // Native ESM named imports only cover statically detected CommonJS exports;
      // lazy accessor exports stay available through the default/CommonJS namespace.
      const output = runConsumer("rspack-esm-lazy-consumer.mjs", [
        'import rspack from "./package/rspack/index.js"',
        "const { baseConfig, rules } = rspack",
        'if (baseConfig === null || typeof baseConfig !== "object") {',
        '  throw new Error("baseConfig was not imported")',
        "}",
        "if (!Array.isArray(rules)) {",
        '  throw new Error("rules was not imported")',
        "}",
        'console.log("rspack ESM lazy exports ok")'
      ])

      expect(output).toContain("rspack ESM lazy exports ok")
    })
  })
})
