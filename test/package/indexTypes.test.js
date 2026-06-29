const { execFileSync } = require("child_process")
const {
  existsSync,
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
    expect(declaration).toContain("Base rspack configuration")
    expect(declaration).toContain("Shared loader rules")
    expect(declaration).toContain("generateRspackConfig")
    expect(declaration).toContain("env")
    expect(declaration).toContain("moduleExists")
  })

  test("rspack compiled output does not statically export lazy properties", () => {
    const compiled = readFileSync(join(outDir, "rspack", "index.js"), "utf8")

    // `export declare const` keeps the lazy values in the generated .d.ts, but
    // the CommonJS output must not contain TypeScript's static named-export
    // placeholders. If those return, Node's native CJS/ESM interop sees the
    // names and `import { baseConfig } from "shakapacker/rspack"` stops
    // throwing, which breaks the documented lazy-export contract below.
    expect(compiled).not.toMatch(/exports\.(baseConfig|rules)\s*=/)
    expect(compiled).toContain(
      'Object.defineProperty(exports, "rules", lazyRules.descriptor)'
    )
    expect(compiled).toContain(
      'Object.defineProperty(exports, "baseConfig", lazyBaseConfig.descriptor)'
    )
  })

  // symlinkSync to node_modules/lib requires elevated privileges on Windows
  // (EPERM), so the native-ESM consumer specs are skipped there; the
  // declaration-emit test above does not symlink and still runs.
  const describeOrSkip = process.platform === "win32" ? describe.skip : describe
  const libDir = join(process.cwd(), "lib")
  const describeOrSkipLib = existsSync(libDir) ? describeOrSkip : describe.skip

  describeOrSkipLib("native ESM consumers", () => {
    beforeAll(() => {
      symlinkSync(
        join(process.cwd(), "node_modules"),
        join(sharedRootDir, "node_modules")
      )
      symlinkSync(libDir, join(sharedRootDir, "lib"))
    })

    const runConsumer = (fileName, lines) => {
      const consumerPath = join(sharedRootDir, fileName)
      writeFileSync(consumerPath, lines.join("\n"))

      return execFileSync(process.execPath, [consumerPath], {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "inherit"]
      })
    }

    describe("compiled CommonJS consumers", () => {
      test("webpack entry ignores baseConfig overrides for normal NODE_ENV builds", () => {
        const output = runConsumer("webpack-cjs-normal-env-consumer.cjs", [
          'const shakapacker = require("./package/index.js")',
          'shakapacker.baseConfig = { mode: "none", entry: { sentinel: "./override.js" } }',
          "const result = shakapacker.generateWebpackConfig()",
          "if (result.entry && result.entry.sentinel) {",
          '  throw new Error("baseConfig override leaked into normal env config")',
          "}",
          'console.log("webpack CJS normal env override ignored")'
        ])

        expect(output).toContain("webpack CJS normal env override ignored")
      })

      test("rspack entry ignores baseConfig overrides for normal NODE_ENV builds", () => {
        const output = runConsumer("rspack-cjs-normal-env-consumer.cjs", [
          'const rspack = require("./package/rspack/index.js")',
          'rspack.baseConfig = { mode: "none", entry: { sentinel: "./override.js" } }',
          "const result = rspack.generateRspackConfig()",
          "if (result.entry && result.entry.sentinel) {",
          '  throw new Error("baseConfig override leaked into normal env config")',
          "}",
          'console.log("rspack CJS normal env override ignored")'
        ])

        expect(output).toContain("rspack CJS normal env override ignored")
      })
    })

    // Lazy values installed only as Object.defineProperty accessors are not
    // statically detectable by Node's cjs-module-lexer, so native ESM named
    // imports for baseConfig/rules throw. Returns that error for assertions.
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
      test("supports native ESM named imports of static exports", () => {
        const output = runConsumer("webpack-esm-named-static-consumer.mjs", [
          'import { generateWebpackConfig, env } from "./package/index.js"',
          'if (typeof generateWebpackConfig !== "function") {',
          '  throw new Error("generateWebpackConfig was not imported")',
          "}",
          'if (typeof env !== "object") {',
          '  throw new Error("env was not imported")',
          "}",
          'console.log("webpack ESM named static imports ok")'
        ])

        expect(output).toContain("webpack ESM named static imports ok")
      })

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

      test("rejects native ESM named imports of lazy exports", () => {
        const error = runFailingConsumer(
          "webpack-esm-named-lazy-consumer.mjs",
          'import { baseConfig } from "./package/index.js"'
        )

        expect(error).toBeDefined()
        expect(error.stderr).toMatch(/Named export 'baseConfig' not found/)
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
