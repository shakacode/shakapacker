const { execFileSync } = require("child_process")
const { mkdtempSync, rmSync, symlinkSync, writeFileSync } = require("fs")
const { join } = require("path")
const { tmpdir } = require("os")

describe("webpack index types", () => {
  // symlinkSync to node_modules/lib requires elevated privileges on Windows
  // (EPERM), so these tsc-compile + native-ESM consumer specs are skipped there.
  const describeOrSkip = process.platform === "win32" ? describe.skip : describe

  // The webpack entry is a CommonJS `export =` object assembled in a local
  // variable, so native ESM consumers must use the default import. These specs
  // compile the package with the project's tsc and exercise the compiled output
  // to lock in that contract (the rspack analogue lives in
  // ./rspack/indexTypes.test.js). Both specs share a single tsc build and
  // node_modules/lib symlinks.
  describeOrSkip("native ESM consumers", () => {
    let sharedRootDir

    beforeAll(() => {
      sharedRootDir = mkdtempSync(join(tmpdir(), "shakapacker-webpack-esm-"))
      const outDir = join(sharedRootDir, "package")

      execFileSync("./node_modules/.bin/tsc", ["--outDir", outDir], {
        // tsc writes diagnostics to stdout; inherit it so a compile failure
        // surfaces readable errors instead of a raw Buffer in the thrown error.
        stdio: ["pipe", "inherit", "inherit"]
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

    test("compiled webpack entry exposes lazy exports via the default import", () => {
      // Reads the property descriptors rather than the values so the lazy
      // loaders (and their manifest side effects) stay deferred; the getter's
      // presence is the contract consumers rely on to override baseConfig/rules.
      const consumerPath = join(
        sharedRootDir,
        "webpack-esm-default-consumer.mjs"
      )
      writeFileSync(
        consumerPath,
        [
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
        ].join("\n")
      )

      const output = execFileSync(process.execPath, [consumerPath], {
        encoding: "utf8",
        stdio: ["pipe", "pipe", "inherit"]
      })

      expect(output).toContain("webpack ESM default import ok")
    })

    test("compiled webpack entry rejects native ESM named imports", () => {
      // Locks in the documented breaking change: the entry's members are not
      // statically detectable by Node's cjs-module-lexer (the object is built in
      // a local variable before `export =`, and baseConfig/rules are installed
      // via Object.defineProperty). A native ESM named import therefore throws
      // SyntaxError at load time; consumers must use the default import (above).
      const consumerPath = join(sharedRootDir, "webpack-esm-named-consumer.mjs")
      writeFileSync(
        consumerPath,
        'import { config } from "./package/index.js"\n' +
          "console.log(typeof config)\n"
      )

      let error
      try {
        execFileSync(process.execPath, [consumerPath], {
          encoding: "utf8",
          stdio: ["pipe", "pipe", "pipe"]
        })
      } catch (caught) {
        error = caught
      }

      expect(error).toBeDefined()
      expect(error.stderr).toMatch(/Named export 'config' not found/)
    })
  })
})
