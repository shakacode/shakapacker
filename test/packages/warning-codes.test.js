const { readFileSync } = require("fs")
const { join, resolve } = require("path")

// Both wrapper packages emit `SHAKAPACKER_BUNDLER_MISMATCH` independently.
// Each package needs its own copy at install time (they ship as
// independent npm packages, so a shared module isn't possible without
// vendoring at publish time). This test fails if the strings drift.

const repoRoot = resolve(__dirname, "../..")
const webpackWrapperPath = join(
  repoRoot,
  "packages/shakapacker-webpack/index.js"
)
const rspackWrapperPath = join(repoRoot, "packages/shakapacker-rspack/index.js")

const extractCodes = (path) => {
  const source = readFileSync(path, "utf8")
  // Scope to assignment lines (e.g. `const NAME = "SHAKAPACKER_..."`)
  // so a future comment containing one of the literal strings doesn't
  // accidentally pass the "declares X" assertions or break the "does
  // not declare Y" assertions. Multiline (`m`) anchors `^` to each
  // line; require leading whitespace + `const`/`let` so only real
  // declarations match.
  return Array.from(
    source.matchAll(/^\s*(?:const|let)\s+\w+\s*=\s*"(SHAKAPACKER_[A-Z_]+)"/gm)
  )
    .map((match) => match[1])
    .sort()
}

const extractReadConfigHelper = (path) => {
  const source = readFileSync(path, "utf8")
  // Match the full `const readShakapackerConfig = () => { ... }` block so
  // we can assert byte-for-byte parity between the two duplicated copies.
  // The block ends at the first line containing only `}` at column 0;
  // both wrappers use that style.
  const match = source.match(/^const readShakapackerConfig =[\s\S]*?^\}/m)
  if (!match) {
    throw new Error(`Could not locate readShakapackerConfig in ${path}`)
  }
  return match[0]
}

describe("warning codes are consistent across wrapper packages", () => {
  test("bundler mismatch code matches between webpack and rspack wrappers", () => {
    const webpackCodes = extractCodes(webpackWrapperPath)
    const rspackCodes = extractCodes(rspackWrapperPath)

    expect(webpackCodes).toContain("SHAKAPACKER_BUNDLER_MISMATCH")
    expect(rspackCodes).toContain("SHAKAPACKER_BUNDLER_MISMATCH")
  })

  test("rspack wrapper does not declare SHAKAPACKER_NO_TRANSPILER", () => {
    // SHAKAPACKER_NO_TRANSPILER is a webpack-only concept (rspack ships
    // SWC built in). Asserting absence here documents intent and prevents
    // a future refactor from accidentally adding the code to the rspack
    // wrapper, which would then need its own gating to avoid spurious
    // warnings.
    const rspackCodes = extractCodes(rspackWrapperPath)

    expect(rspackCodes).not.toContain("SHAKAPACKER_NO_TRANSPILER")
  })
})

describe("readShakapackerConfig parity across wrapper packages", () => {
  // The helper is intentionally duplicated verbatim in both wrappers
  // (they ship as independent npm packages, so sharing a module isn't
  // possible without vendoring at publish time). A textual identity
  // check is cheaper and stronger than a behavioral fixture: it catches
  // any drift, including renames, comment edits, and reordered branches
  // that would silently leave one wrapper behind the other.
  test("readShakapackerConfig is byte-for-byte identical in both wrappers", () => {
    const webpackHelper = extractReadConfigHelper(webpackWrapperPath)
    const rspackHelper = extractReadConfigHelper(rspackWrapperPath)

    expect(webpackHelper).toBe(rspackHelper)
  })
})
