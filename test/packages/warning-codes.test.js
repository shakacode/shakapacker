const { readFileSync } = require("fs")
const { join, resolve } = require("path")

// Both wrapper packages emit `SHAKAPACKER_BUNDLER_MISMATCH` independently.
// Each package needs its own copy at install time (they ship as
// independent npm packages, so a shared module isn't possible without
// vendoring at publish time). This test fails if the strings drift.

const repoRoot = resolve(__dirname, "../..")

const extractCodes = (path) => {
  const source = readFileSync(path, "utf8")
  // Each wrapper declares its codes as `const NAME = "SHAKAPACKER_..."`;
  // matching the literal lets us assert string-level equality regardless
  // of how the constant is referenced later in `process.emitWarning`.
  return Array.from(source.matchAll(/"(SHAKAPACKER_[A-Z_]+)"/g))
    .map((match) => match[1])
    .sort()
}

describe("warning codes are consistent across wrapper packages", () => {
  test("bundler mismatch code matches between webpack and rspack wrappers", () => {
    const webpackCodes = extractCodes(
      join(repoRoot, "packages/shakapacker-webpack/index.js")
    )
    const rspackCodes = extractCodes(
      join(repoRoot, "packages/shakapacker-rspack/index.js")
    )

    expect(webpackCodes).toContain("SHAKAPACKER_BUNDLER_MISMATCH")
    expect(rspackCodes).toContain("SHAKAPACKER_BUNDLER_MISMATCH")
  })

  test("rspack wrapper does not declare SHAKAPACKER_NO_TRANSPILER", () => {
    // SHAKAPACKER_NO_TRANSPILER is a webpack-only concept (rspack ships
    // SWC built in). Asserting absence here documents intent and prevents
    // a future refactor from accidentally adding the code to the rspack
    // wrapper, which would then need its own gating to avoid spurious
    // warnings.
    const rspackCodes = extractCodes(
      join(repoRoot, "packages/shakapacker-rspack/index.js")
    )

    expect(rspackCodes).not.toContain("SHAKAPACKER_NO_TRANSPILER")
  })
})
