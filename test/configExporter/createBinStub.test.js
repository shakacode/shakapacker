const {
  accessSync,
  constants,
  mkdtempSync,
  readFileSync,
  rmSync
} = require("fs")
const { join, resolve } = require("path")
const { tmpdir } = require("os")
const { createBinStub } = require("../../package/configExporter/cli")

const gemRoot = resolve(__dirname, "../..")

// The Ruby logic in lib/install/bin/shakapacker-config and
// lib/install/bin/diff-bundler-config is also duplicated inside the
// `createBinStub` template in package/configExporter/cli.ts. The Ruby spec
// (spec/shakapacker/binstub_sync_spec.rb) keeps the three checked-in copies
// (install template, install diff template, and the dummy app's binstub)
// honest, but it cannot reach into the JS template. This test closes that
// gap by invoking createBinStub for both helper names and asserting the
// generated content matches the corresponding lib/install/bin/* file.
describe("createBinStub template parity", () => {
  let tmp

  beforeEach(() => {
    tmp = mkdtempSync(join(tmpdir(), "shakapacker-createBinStub-"))
  })

  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true })
  })

  // diff-bundler-config is a white-box parity case; production init only
  // generates shakapacker-config.
  test.each(["shakapacker-config", "diff-bundler-config"])(
    "generates lib/install/bin/%s byte-for-byte",
    (binstubName) => {
      const generatedPath = join(tmp, "bin", binstubName)
      createBinStub(generatedPath)

      const generated = readFileSync(generatedPath, "utf8")
      const installed = readFileSync(
        join(gemRoot, "lib", "install", "bin", binstubName),
        "utf8"
      )

      expect(generated).toBe(installed)
      expect(generated).toContain(
        "# This binstub is managed by Shakapacker. Regenerate it by rerunning the install or init command."
      )
      expect(generated).not.toContain("# Keep helper logic in sync across:")
      expect(generated).not.toContain("package/configExporter/cli.ts")
      expect(() => accessSync(generatedPath, constants.X_OK)).not.toThrow()
    }
  )
})
