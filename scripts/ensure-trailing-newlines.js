#!/usr/bin/env node

/**
 * Ensure all JavaScript files have trailing newlines
 *
 * This script is run after TypeScript compilation to ensure all generated
 * JS files end with a newline character, as required by the project's
 * linting rules (per CLAUDE.md).
 */

const fs = require("fs")
const { execSync } = require("child_process")

// Find all generated JS files in package directory
const findJsFiles = () => {
  const stdout = execSync('find package -name "*.js" -type f', {
    encoding: "utf8"
  })
  return stdout.trim().split("\n").filter(Boolean)
}

const ensureTrailingNewline = (filePath) => {
  const content = fs.readFileSync(filePath, "utf8")

  // Check if file already ends with newline
  if (!content.endsWith("\n")) {
    // eslint-disable-next-line no-console
    console.log(`Adding trailing newline to: ${filePath}`)
    fs.writeFileSync(filePath, `${content}\n`)
    return true
  }
  return false
}

// Main execution
try {
  const jsFiles = findJsFiles()
  let fixedCount = 0

  jsFiles.forEach((file) => {
    if (ensureTrailingNewline(file)) {
      fixedCount += 1
    }
  })

  if (fixedCount > 0) {
    // eslint-disable-next-line no-console
    console.log(`✅ Fixed ${fixedCount} file(s) with missing trailing newlines`)
  } else {
    // eslint-disable-next-line no-console
    console.log("✅ All JavaScript files already have trailing newlines")
  }

  process.exit(0)
} catch (error) {
  // eslint-disable-next-line no-console
  console.error("Error ensuring trailing newlines:", error.message)
  process.exit(1)
}
