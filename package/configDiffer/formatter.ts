import { dump as dumpYaml } from "js-yaml"
import { DiffResult, DiffEntry, DiffOperation } from "./types"

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

  formatSummary(result: DiffResult): string {
    const lines: string[] = []

    lines.push("=".repeat(80))
    lines.push("Configuration Diff Summary")
    lines.push("=".repeat(80))
    lines.push("")

    lines.push("Total Changes: " + result.summary.totalChanges)
    lines.push("  Added:       " + result.summary.added)
    lines.push("  Removed:     " + result.summary.removed)
    lines.push("  Changed:     " + result.summary.changed)
    if (result.summary.unchanged !== undefined) {
      lines.push("  Unchanged:   " + result.summary.unchanged)
    }

    if (result.summary.totalChanges === 0) {
      lines.push("")
      lines.push("✅ No differences found - configurations are identical")
    }

    lines.push("")
    return lines.join("\n")
  }

  formatDetailed(result: DiffResult): string {
    const lines: string[] = []

    lines.push("=".repeat(80))
    lines.push("Configuration Diff - Detailed Report")
    lines.push("=".repeat(80))
    lines.push("")

    lines.push(`Compared at: ${result.metadata.comparedAt}`)
    if (result.metadata.leftFile && result.metadata.rightFile) {
      lines.push(`Left:  ${result.metadata.leftFile}`)
      lines.push(`Right: ${result.metadata.rightFile}`)
    }
    lines.push("")

    lines.push(this.formatSummary(result))

    if (result.summary.totalChanges > 0) {
      lines.push("=".repeat(80))
      lines.push("Changes")
      lines.push("=".repeat(80))
      lines.push("")

      const grouped = this.groupByOperation(result.entries)

      if (grouped.added && grouped.added.length > 0) {
        lines.push("➕ ADDED (" + grouped.added.length + ")")
        lines.push("-".repeat(80))
        grouped.added.forEach((entry) => {
          lines.push(this.formatEntry(entry))
        })
        lines.push("")
      }

      if (grouped.removed && grouped.removed.length > 0) {
        lines.push("➖ REMOVED (" + grouped.removed.length + ")")
        lines.push("-".repeat(80))
        grouped.removed.forEach((entry) => {
          lines.push(this.formatEntry(entry))
        })
        lines.push("")
      }

      if (grouped.changed && grouped.changed.length > 0) {
        lines.push("🔄 CHANGED (" + grouped.changed.length + ")")
        lines.push("-".repeat(80))
        grouped.changed.forEach((entry) => {
          lines.push(this.formatEntry(entry))
        })
        lines.push("")
      }
    }

    lines.push("=".repeat(80))
    lines.push("")

    return lines.join("\n")
  }

  private formatEntry(entry: DiffEntry): string {
    const lines: string[] = []
    const indent = "  "

    lines.push(`${indent}Path: ${entry.path.humanPath}`)
    lines.push(`${indent}Type: ${entry.valueType}`)

    if (entry.operation === "added") {
      lines.push(`${indent}Value: ${this.formatValue(entry.newValue)}`)
    } else if (entry.operation === "removed") {
      lines.push(`${indent}Value: ${this.formatValue(entry.oldValue)}`)
    } else if (entry.operation === "changed") {
      lines.push(`${indent}Old: ${this.formatValue(entry.oldValue)}`)
      lines.push(`${indent}New: ${this.formatValue(entry.newValue)}`)
    }

    lines.push("")
    return lines.join("\n")
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
