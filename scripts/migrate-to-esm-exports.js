#!/usr/bin/env node
/* eslint-disable no-console, no-restricted-syntax, no-plusplus */

/**
 * Migration script for Shakapacker v10 ESM exports
 *
 * This script helps migrate your codebase from CommonJS-style imports
 * to the new ES module exports in Shakapacker v10.
 *
 * Usage:
 *   node scripts/migrate-to-esm-exports.js [file-or-directory]
 *
 * Examples:
 *   node scripts/migrate-to-esm-exports.js config/webpack/webpack.config.js
 *   node scripts/migrate-to-esm-exports.js config/webpack/
 *
 * What it does:
 * - Converts require('shakapacker') to import { ... } from 'shakapacker'
 * - Updates shakapacker.config to just config
 * - Updates shakapacker.env.* to destructured env properties
 * - Preserves other require() calls that aren't related to shakapacker
 */

const fs = require("fs")
const path = require("path")

function migrateFile(filePath) {
  const content = fs.readFileSync(filePath, "utf8")
  let modified = content

  // Pattern 1: const shakapacker = require('shakapacker')
  // Convert to: import * as shakapacker from 'shakapacker' (for backward compat)
  modified = modified.replace(
    /const\s+(\w+)\s*=\s*require\(['"]shakapacker['"]\)/g,
    "import * as $1 from 'shakapacker'"
  )

  // Pattern 2: const { config, env, ... } = require('shakapacker')
  // Convert to: import { config, railsEnv, nodeEnv, ... } from 'shakapacker'
  modified = modified.replace(
    /const\s*\{\s*([^}]+)\}\s*=\s*require\(['"]shakapacker['"]\)/g,
    (match, exports) => {
      // Replace 'env' with individual env exports
      let newExports = exports
      if (newExports.includes("env")) {
        newExports = newExports.replace(
          /env/g,
          "railsEnv, nodeEnv, isProduction, isDevelopment, runningWebpackDevServer"
        )
      }
      return `import { ${newExports} } from 'shakapacker'`
    }
  )

  // Pattern 3: shakapacker.config -> config (if shakapacker was imported as namespace)
  // This handles cases where someone does: const shakapacker = require('shakapacker'); shakapacker.config
  modified = modified.replace(
    /(\w+)\.config(?=\s|;|,|\)|\]|})/g,
    (match, varName) => {
      // Only replace if this looks like it was the shakapacker import
      if (
        content.includes(`${varName} = require('shakapacker')`) ||
        content.includes(`import * as ${varName} from 'shakapacker'`)
      ) {
        return "config"
      }
      return match
    }
  )

  // Pattern 4: shakapacker.env.nodeEnv -> nodeEnv
  modified = modified.replace(
    /(\w+)\.env\.(railsEnv|nodeEnv|isProduction|isDevelopment|runningWebpackDevServer)/g,
    (match, varName, envProp) => {
      if (
        content.includes(`${varName} = require('shakapacker')`) ||
        content.includes(`import * as ${varName} from 'shakapacker'`)
      ) {
        return envProp
      }
      return match
    }
  )

  // Only write if changes were made
  if (modified !== content) {
    fs.writeFileSync(filePath, modified, "utf8")
    console.log(`✅ Migrated: ${filePath}`)
    return true
  }

  return false
}

function processPath(targetPath) {
  const stats = fs.statSync(targetPath)

  if (stats.isDirectory()) {
    const files = fs.readdirSync(targetPath)
    let migratedCount = 0

    for (const file of files) {
      const filePath = path.join(targetPath, file)
      const fileStats = fs.statSync(filePath)

      if (fileStats.isDirectory()) {
        migratedCount += processPath(filePath)
      } else if (file.match(/\.(js|ts|jsx|tsx)$/)) {
        if (migrateFile(filePath)) {
          migratedCount++
        }
      }
    }

    return migratedCount
  }
  if (targetPath.match(/\.(js|ts|jsx|tsx)$/)) {
    return migrateFile(targetPath) ? 1 : 0
  }

  return 0
}

// Main execution
const targetPath = process.argv[2]

if (!targetPath) {
  console.error("❌ Error: Please provide a file or directory path")
  console.error("")
  console.error(
    "Usage: node scripts/migrate-to-esm-exports.js [file-or-directory]"
  )
  console.error("")
  console.error("Examples:")
  console.error(
    "  node scripts/migrate-to-esm-exports.js config/webpack/webpack.config.js"
  )
  console.error("  node scripts/migrate-to-esm-exports.js config/webpack/")
  process.exit(1)
}

if (!fs.existsSync(targetPath)) {
  console.error(`❌ Error: Path not found: ${targetPath}`)
  process.exit(1)
}

console.log("🚀 Starting Shakapacker v10 ESM migration...")
console.log("")

const migratedCount = processPath(targetPath)

console.log("")
console.log(`✨ Migration complete! Migrated ${migratedCount} file(s).`)
console.log("")
console.log("⚠️  Please review the changes and test your application.")
console.log("   Some manual adjustments may still be needed for complex cases.")
