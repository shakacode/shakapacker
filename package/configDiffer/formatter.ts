import { dump as dumpYaml } from "js-yaml"
import { DiffResult, DiffEntry, DiffOperation } from "./types"
import { getDocForKey } from "./configDocs"

export class DiffFormatter {
  formatJson(result: DiffResult): string {
    return JSON.stringify(result, null, 2)
  }

  formatYaml(result: DiffResult): string {
    const formatted = {
      metadata: result.metadata,
      summary: result.summary,
      changes: this.groupByOperation(result.entries)
    }

    return dumpYaml(formatted, {
      indent: 2,
      lineWidth: 120,
      noRefs: true,
      sortKeys: false
    })
  }

  formatContextual(result: DiffResult): string {
    const lines: string[] = []

    // Extract short names from filenames
    const leftLabel = this.getShortLabel(result.metadata.leftFile, "left")
    const rightLabel = this.getShortLabel(result.metadata.rightFile, "right")

    lines.push("=".repeat(80))
    lines.push("Webpack/Rspack Configuration Comparison")
    lines.push("=".repeat(80))
    lines.push("")

    if (result.metadata.leftFile && result.metadata.rightFile) {
      lines.push(`Comparing: ${result.metadata.leftFile}`)
      lines.push(`      vs:  ${result.metadata.rightFile}`)
      lines.push("")
    }

    if (result.summary.totalChanges === 0) {
      lines.push("✅ No differences found - configurations are identical")
      lines.push("")
      return lines.join("\n")
    }

    lines.push(
      `Found ${result.summary.totalChanges} difference(s): ` +
        `${result.summary.added} added, ${result.summary.removed} removed, ${result.summary.changed} changed`
    )
    lines.push("")
    lines.push("=".repeat(80))
    lines.push("")

    // Group and sort entries for better readability
    const sortedEntries = [...result.entries].sort((a, b) => {
      // Sort by path depth first (shallower first), then alphabetically
      if (a.path.path.length !== b.path.path.length) {
        return a.path.path.length - b.path.path.length
      }
      return a.path.humanPath.localeCompare(b.path.humanPath)
    })

    sortedEntries.forEach((entry, index) => {
      if (entry.operation === "unchanged") return

      lines.push(
        this.formatContextualEntry(entry, index + 1, leftLabel, rightLabel)
      )
      lines.push("")
    })

    lines.push("=".repeat(80))
    lines.push("")
    lines.push("Legend:")
    lines.push(`  [+] = Added in ${rightLabel}`)
    lines.push(`  [-] = Removed from ${rightLabel}`)
    lines.push(`  [~] = Changed between configs`)
    lines.push("")

    return lines.join("\n")
  }

  private getShortLabel(
    filename: string | undefined,
    fallback: string
  ): string {
    if (!filename) return fallback

    // Extract meaningful short name from filename
    // Examples:
    //   webpack-development-client.yaml -> dev-client
    //   webpack-production-server.yaml -> prod-server
    //   shakapacker-config-exports/webpack-development-client.yaml -> dev-client
    const basename = filename.split("/").pop() || filename
    const withoutExt = basename.replace(/\.(yaml|yml|json|js|ts)$/, "")

    // Try to extract env-type pattern
    const match = withoutExt.match(
      /(development|production|test|dev|prod).*?(client|server)/i
    )
    if (match) {
      const env = match[1]
        .toLowerCase()
        .replace("development", "dev")
        .replace("production", "prod")
      const type = match[2].toLowerCase()
      return `${env}-${type}`
    }

    // Try to extract just the env
    const envMatch = withoutExt.match(/(development|production|test|dev|prod)/i)
    if (envMatch) {
      return envMatch[1]
        .toLowerCase()
        .replace("development", "dev")
        .replace("production", "prod")
    }

    // Fall back to basename without extension, shortened
    if (withoutExt.length > 20) {
      return `${withoutExt.substring(0, 17)}...`
    }

    return withoutExt
  }

  // Keep formatDetailed as an alias for backward compatibility
  formatDetailed(result: DiffResult): string {
    return this.formatContextual(result)
  }

  // Simplified summary - just counts
  formatSummary(result: DiffResult): string {
    if (result.summary.totalChanges === 0) {
      return "✅ No differences found"
    }

    return (
      `${result.summary.totalChanges} changes: ` +
      `+${result.summary.added} -${result.summary.removed} ~${result.summary.changed}`
    )
  }

  private formatContextualEntry(
    entry: DiffEntry,
    index: number,
    leftLabel: string,
    rightLabel: string
  ): string {
    const lines: string[] = []
    const symbolMap: Record<string, string> = {
      added: "[+]",
      removed: "[-]",
      changed: "[~]"
    }
    const symbol = symbolMap[entry.operation] || "[~]"

    lines.push(`${index}. ${symbol} ${entry.path.humanPath}`)
    lines.push("")

    // Add documentation if available
    const doc = getDocForKey(entry.path.humanPath)
    if (doc) {
      lines.push(`   What it does:`)
      lines.push(`   ${doc.description}`)
      lines.push("")

      if (doc.affects) {
        lines.push(`   Affects: ${doc.affects}`)
        lines.push("")
      }

      if (doc.defaultValue) {
        lines.push(`   Default: ${doc.defaultValue}`)
        lines.push("")
      }
    }

    // Show the values from each file with their labels
    lines.push(`   Values:`)
    if (entry.operation === "added") {
      lines.push(`     ${leftLabel}:  <not set>`)
      lines.push(`     ${rightLabel}: ${this.formatValue(entry.newValue)}`)
    } else if (entry.operation === "removed") {
      lines.push(`     ${leftLabel}:  ${this.formatValue(entry.oldValue)}`)
      lines.push(`     ${rightLabel}: <not set>`)
    } else if (entry.operation === "changed") {
      lines.push(`     ${leftLabel}:  ${this.formatValue(entry.oldValue)}`)
      lines.push(`     ${rightLabel}: ${this.formatValue(entry.newValue)}`)

      // Add impact analysis for specific keys
      const impact = this.analyzeImpact(entry)
      if (impact) {
        lines.push("")
        lines.push(`   Impact: ${impact}`)
      }
    }

    // Add documentation link if available
    if (doc && doc.documentationUrl) {
      lines.push("")
      lines.push(`   Documentation: ${doc.documentationUrl}`)
    }

    return lines.join("\n")
  }

  private analyzeImpact(entry: DiffEntry): string | null {
    const path = entry.path.humanPath
    const newVal = entry.newValue

    // Specific impact analysis
    if (path === "mode") {
      if (newVal === "production") {
        return "Enabling production optimizations (minification, tree-shaking)"
      }
      if (newVal === "development") {
        return "Enabling development features (better error messages, faster builds)"
      }
    }

    if (path === "optimization.minimize") {
      if (newVal === true || newVal === "true") {
        return "Code will be minified - smaller bundles but slower builds"
      }
      return "Minification disabled - larger bundles but faster builds"
    }

    if (path === "devtool") {
      if (newVal === "source-map") {
        return "Full source maps - best debugging but slower builds"
      }
      if (newVal === "eval") {
        return "Fastest builds but poor debugging experience"
      }
      if (String(newVal).includes("cheap") || String(newVal).includes("eval")) {
        return "Faster builds with some debugging capability"
      }
    }

    if (path.includes("output.filename")) {
      if (String(newVal).includes("[contenthash]")) {
        return "Cache busting enabled - better long-term caching"
      }
    }

    return null
  }

  private formatValue(value: any): string {
    if (value === null) return "null"
    if (value === undefined) return "undefined"

    if (typeof value === "string") {
      if (value.length > 100) {
        return `"${value.substring(0, 97)}..."`
      }
      return `"${value}"`
    }

    if (typeof value === "number" || typeof value === "boolean") {
      return String(value)
    }

    return JSON.stringify(value)
  }

  private groupByOperation(
    entries: DiffEntry[]
  ): Record<DiffOperation, DiffEntry[]> {
    const grouped: Record<string, DiffEntry[]> = {
      added: [],
      removed: [],
      changed: [],
      unchanged: []
    }

    for (const entry of entries) {
      grouped[entry.operation].push(entry)
    }

    return grouped as Record<DiffOperation, DiffEntry[]>
  }
}
