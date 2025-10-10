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
 * - Creates timestamped backup files before any modifications (.backup-TIMESTAMP)
 * - Converts require('shakapacker') to import { ... } from 'shakapacker'
 * - Updates shakapacker.config to just config
 * - Updates shakapacker.env.* to destructured env properties
 * - Converts module.exports = ... to export default ... (prevents mixed CJS/ESM)
 * - Preserves other require() calls that aren't related to shakapacker
 * - Aborts on backup failure to prevent data loss
 */

const fs = require("fs")
const path = require("path")

function createBackup(filePath) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-")
  const backupPath = `${filePath}.backup-${timestamp}`

  try {
    fs.copyFileSync(filePath, backupPath)
    return backupPath
  } catch (error) {
    console.error(
      `❌ Failed to create backup for ${filePath}: ${error.message}`
    )
    throw new Error(
      `Backup failed for ${filePath}. Aborting migration to prevent data loss.`
    )
  }
}

function migrateFile(filePath) {
  const content = fs.readFileSync(filePath, "utf8")
  let modified = content
  let hasChanges = false

  // Pattern 1: const shakapacker = require('shakapacker')
  // Convert to: import * as shakapacker from 'shakapacker' (for backward compat)
  const pattern1 = /const\s+(\w+)\s*=\s*require\(['"]shakapacker['"]\)/g
  if (pattern1.test(content)) {
    modified = modified.replace(
      /const\s+(\w+)\s*=\s*require\(['"]shakapacker['"]\)/g,
      "import * as $1 from 'shakapacker'"
    )
    hasChanges = true
  }

  // Pattern 2: const { config, env, ... } = require('shakapacker')
  // Convert to: import { config, railsEnv, nodeEnv, ... } from 'shakapacker'
  const pattern2 =
    /const\s*\{\s*([^}]+)\}\s*=\s*require\(['"]shakapacker['"]\)/g
  if (pattern2.test(content)) {
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
    hasChanges = true
  }

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
        hasChanges = true
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
        hasChanges = true
        return envProp
      }
      return match
    }
  )

  // Pattern 5: module.exports = ... -> export default ...
  // This prevents mixing ESM imports with CJS exports (which causes SyntaxError)
  const pattern5 = /^(\s*)module\.exports\s*=\s*/gm
  if (pattern5.test(modified)) {
    modified = modified.replace(
      /^(\s*)module\.exports\s*=\s*/gm,
      "$1export default "
    )
    hasChanges = true
  }

  // Only write if changes were made
  if (hasChanges && modified !== content) {
    // Create backup before modifying
    const backupPath = createBackup(filePath)

    try {
      fs.writeFileSync(filePath, modified, "utf8")
      console.log(`✅ Migrated: ${filePath}`)
      console.log(`   Backup: ${backupPath}`)
      return true
    } catch (error) {
      console.error(`❌ Failed to write ${filePath}: ${error.message}`)
      console.error(`   Original file preserved in backup: ${backupPath}`)
      return false
    }
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
if (migratedCount > 0) {
  console.log("📦 Backup files created with .backup-TIMESTAMP extension")
  console.log("   You can restore from backups if needed")
  console.log("")
}
console.log("⚠️  Next steps:")
console.log("   1. Review the changes carefully")
console.log("   2. Test your webpack/rspack build")
console.log("   3. Delete backup files once you've verified everything works")
console.log("   4. Some manual adjustments may be needed for complex cases")
