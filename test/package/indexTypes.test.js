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

// These specs compile the package once with the project's tsc and exercise the
// compiled output for both the webpack and rspack entry points: declaration
// emit plus the native-ESM import contracts all share the single build below.
describe("compiled package output", () => {
  let sharedRootDir
  let outDir

  beforeAll(() => {
    sharedRootDir = mkdtempSync(join(tmpdir(), "shakapacker-compiled-"))
    outDir = join(sharedRootDir, "package")

    execFileSync("./node_modules/.bin/tsc", ["--outDir", outDir], {
      // tsc writes diagnostics to stdout; inherit it so a compile failure
      // surfaces readable errors instead of a raw Buffer in the thrown error.
      stdio: ["pipe", "inherit", "inherit"]
    })
  }, 60000)

  afterAll(() => {
    if (sharedRootDir) {
      rmSync(sharedRootDir, { recursive: true, force: true })
    }
  })

  test("rspack declaration emit includes the lazy export properties", () => {
    // tsconfig.json sets `declaration: true`, so the shared build above emits
    // the .d.ts files alongside the compiled JS.
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
  })

  // symlinkSync to node_modules/lib requires elevated privileges on Windows
  // (EPERM), so the native-ESM consumer specs are skipped there; the
  // declaration-emit test above does not symlink and still runs.
  const describeOrSkip = process.platform === "win32" ? describe.skip : describe

  describeOrSkip("native ESM consumers", () => {
    beforeAll(() => {
      symlinkSync(
        join(process.cwd(), "node_modules"),
        join(sharedRootDir, "node_modules")
      )
      symlinkSync(join(process.cwd(), "lib"), join(sharedRootDir, "lib"))
    })

    const runConsumer = (fileName, lines) => {
      const consumerPath = join(sharedRootDir, fileName)
      writeFileSync(consumerPath, lines.join("\n"))

      return execFileSync(process.execPath, [consumerPath], {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "inherit"]
      })
    }

    // Locks in the documented breaking change: members assembled in a local
    // object before `export =` (webpack entry) or installed as lazy getters via
    // Object.defineProperty (rspack entry) are not statically detectable by
    // Node's cjs-module-lexer, so a native ESM named import throws SyntaxError
    // at load time; consumers must use the default import. This also guards
    // against a future toolchain change silently re-enabling the named import.
    // Returns the error thrown by the consumer process for the test to assert.
    const runFailingConsumer = (fileName, importLine) => {
      const consumerPath = join(sharedRootDir, fileName)
      writeFileSync(consumerPath, `${importLine}\n`)

      let error
      try {
        execFileSync(process.execPath, [consumerPath], {
          encoding: "utf8",
          stdio: ["pipe", "pipe", "pipe"]
        })
      } catch (caught) {
        error = caught
      }

      return error
    }

    describe("webpack entry", () => {
      test("exposes lazy exports via the default import", () => {
        // Reads the property descriptors rather than the values so the lazy
        // loaders (and their manifest side effects) stay deferred; the getter's
        // presence is the contract consumers rely on to override
        // baseConfig/rules.
        const output = runConsumer("webpack-esm-default-consumer.mjs", [
          'import shakapacker from "./package/index.js"',
          'if (typeof shakapacker.config !== "object") {',
          '  throw new Error("config was not exposed on the default import")',
          "}",
          'for (const key of ["baseConfig", "rules"]) {',
          "  const descriptor = Object.getOwnPropertyDescriptor(shakapacker, key)",
          '  if (typeof descriptor?.get !== "function") {',
          '    throw new Error(key + " is not a lazy getter")',
          "  }",
          "}",
          'console.log("webpack ESM default import ok")'
        ])

        expect(output).toContain("webpack ESM default import ok")
      })

      test("rejects native ESM named imports", () => {
        const error = runFailingConsumer(
          "webpack-esm-named-consumer.mjs",
          'import { config } from "./package/index.js"'
        )

        expect(error).toBeDefined()
        expect(error.stderr).toMatch(/Named export 'config' not found/)
      })
    })

    describe("rspack entry", () => {
      test("supports native ESM named imports of static exports", () => {
        const output = runConsumer("rspack-esm-consumer.mjs", [
          'import { generateRspackConfig } from "./package/rspack/index.js"',
          'if (typeof generateRspackConfig !== "function") {',
          '  throw new Error("generateRspackConfig was not imported")',
          "}",
          'console.log("rspack ESM named imports ok")'
        ])

        expect(output).toContain("rspack ESM named imports ok")
      })

      test("exposes working lazy exports via the default import", () => {
        // Native ESM named imports only cover statically detected CommonJS
        // exports; lazy accessor exports stay available through the
        // default/CommonJS namespace. The descriptor check verifies the lazy
        // getters were actually installed on the compiled output (the ambient
        // `declare const`s emit no binding of their own, so a missing getter
        // would otherwise surface as a `void 0` placeholder).
        const output = runConsumer("rspack-esm-lazy-consumer.mjs", [
          'import rspack from "./package/rspack/index.js"',
          'for (const key of ["baseConfig", "rules"]) {',
          "  const descriptor = Object.getOwnPropertyDescriptor(rspack, key)",
          '  if (typeof descriptor?.get !== "function") {',
          '    throw new Error(key + " is not a lazy getter")',
          "  }",
          "}",
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

      test("rejects native ESM named imports of lazy exports", () => {
        const error = runFailingConsumer(
          "rspack-esm-named-lazy-consumer.mjs",
          'import { baseConfig } from "./package/rspack/index.js"'
        )

        expect(error).toBeDefined()
        expect(error.stderr).toMatch(/Named export 'baseConfig' not found/)
      })
    })
  })
})
