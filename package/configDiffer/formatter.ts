import { dump as dumpYaml } from "js-yaml"
import { DiffResult, DiffEntry, DiffOperation } from "./types"
import { getDocForKey, hasDocumentation } from "./configDocs"

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

      lines.push(this.formatContextualEntry(entry, index + 1))
      lines.push("")
    })

    lines.push("=".repeat(80))
    lines.push("")
    lines.push("Legend:")
    lines.push("  [+] = Added in right config")
    lines.push("  [-] = Removed from right config")
    lines.push("  [~] = Changed between configs")
    lines.push("")

    return lines.join("\n")
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

  private formatContextualEntry(entry: DiffEntry, index: number): string {
    const lines: string[] = []
    const symbol =
      entry.operation === "added"
        ? "[+]"
        : entry.operation === "removed"
          ? "[-]"
          : "[~]"

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

    // Show the change
    if (entry.operation === "added") {
      lines.push(`   Added value: ${this.formatValue(entry.newValue)}`)
    } else if (entry.operation === "removed") {
      lines.push(`   Removed value: ${this.formatValue(entry.oldValue)}`)
    } else if (entry.operation === "changed") {
      lines.push(`   Old value: ${this.formatValue(entry.oldValue)}`)
      lines.push(`   New value: ${this.formatValue(entry.newValue)}`)

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
    const oldVal = entry.oldValue
    const newVal = entry.newValue

    // Specific impact analysis
    if (path === "mode") {
      if (newVal === "production") {
        return "Enabling production optimizations (minification, tree-shaking)"
      } else if (newVal === "development") {
        return "Enabling development features (better error messages, faster builds)"
      }
    }

    if (path === "optimization.minimize") {
      if (newVal === true || newVal === "true") {
        return "Code will be minified - smaller bundles but slower builds"
      } else {
        return "Minification disabled - larger bundles but faster builds"
      }
    }

    if (path === "devtool") {
      if (newVal === "source-map") {
        return "Full source maps - best debugging but slower builds"
      } else if (newVal === "eval") {
        return "Fastest builds but poor debugging experience"
      } else if (
        String(newVal).includes("cheap") ||
        String(newVal).includes("eval")
      ) {
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
