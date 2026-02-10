import {
  DiffOperation,
  DiffEntry,
  DiffResult,
  DiffOptions,
  DiffPath
} from "./types"

export class DiffEngine {
  private options: Required<DiffOptions>

  private entries: DiffEntry[] = []

  constructor(options: DiffOptions = {}) {
    this.options = {
      includeUnchanged: options.includeUnchanged ?? false,
      maxDepth: options.maxDepth ?? null,
      ignoreKeys: options.ignoreKeys ?? [],
      ignorePaths: options.ignorePaths ?? [],
      format: options.format ?? "detailed",
      normalizePaths: options.normalizePaths ?? true,
      pathSeparator: options.pathSeparator ?? "."
    }
  }

  compare(left: any, right: any, metadata?: any): DiffResult {
    this.entries = []
    this.compareValues(left, right, [])

    const summary = this.calculateSummary()

    return {
      summary,
      entries: this.entries,
      metadata: {
        comparedAt: new Date().toISOString(),
        ...metadata
      }
    }
  }

  private compareValues(
    left: any,
    right: any,
    path: string[],
    depth: number = 0
  ): void {
    if (this.shouldIgnorePath(path)) {
      return
    }

    if (this.options.maxDepth !== null && depth > this.options.maxDepth) {
      return
    }

    const leftType = this.getValueType(left)
    const rightType = this.getValueType(right)

    if (left === undefined && right === undefined) {
      return
    }

    if (left === undefined) {
      this.addEntry("added", path, undefined, right, rightType)
      return
    }

    if (right === undefined) {
      this.addEntry("removed", path, left, undefined, leftType)
      return
    }

    if (this.isPrimitive(left) || this.isPrimitive(right)) {
      if (!this.areEqual(left, right)) {
        this.addEntry("changed", path, left, right, leftType)
      } else if (this.options.includeUnchanged) {
        this.addEntry("unchanged", path, left, right, leftType)
      }
      return
    }

    if (Array.isArray(left) && Array.isArray(right)) {
      this.compareArrays(left, right, path, depth)
      return
    }

    if (this.isObject(left) && this.isObject(right)) {
      this.compareObjects(left, right, path, depth)
      return
    }

    if (!this.areEqual(left, right)) {
      this.addEntry("changed", path, left, right, leftType)
    } else if (this.options.includeUnchanged) {
      this.addEntry("unchanged", path, left, right, leftType)
    }
  }

  private compareObjects(
    left: Record<string, any>,
    right: Record<string, any>,
    path: string[],
    depth: number
  ): void {
    const allKeys = new Set([...Object.keys(left), ...Object.keys(right)])

    for (const key of allKeys) {
      if (!this.options.ignoreKeys.includes(key)) {
        const newPath = [...path, key]
        this.compareValues(left[key], right[key], newPath, depth + 1)
      }
    }
  }

  private compareArrays(
    left: any[],
    right: any[],
    path: string[],
    depth: number
  ): void {
    const maxLength = Math.max(left.length, right.length)

    for (let i = 0; i < maxLength; i += 1) {
      const newPath = [...path, `[${i}]`]
      this.compareValues(left[i], right[i], newPath, depth + 1)
    }
  }

  private addEntry(
    operation: DiffOperation,
    path: string[],
    oldValue: any,
    newValue: any,
    valueType?: string
  ): void {
    const entry: DiffEntry = {
      operation,
      path: this.formatPath(path),
      oldValue: this.serializeValue(oldValue),
      newValue: this.serializeValue(newValue),
      valueType: valueType || this.getValueType(newValue || oldValue)
    }

    this.entries.push(entry)
  }

  private formatPath(path: string[]): DiffPath {
    return {
      path,
      humanPath: this.createHumanPath(path)
    }
  }

  private createHumanPath(path: string[]): string {
    if (path.length === 0) {
      return "(root)"
    }

    return path.join(this.options.pathSeparator)
  }

  private shouldIgnorePath(path: string[]): boolean {
    const humanPath = this.createHumanPath(path)
    return this.options.ignorePaths.some((ignorePath) => {
      if (ignorePath.includes("*")) {
        const escapedPattern = ignorePath
          .replace(/\./g, "\\.")
          .replace(/\*/g, ".*")
        const pattern = new RegExp(`^${escapedPattern}$`)
        return pattern.test(humanPath)
      }
      return humanPath === ignorePath || humanPath.startsWith(`${ignorePath}.`)
    })
  }

  private isPrimitive(value: any): boolean {
    return (
      value === null ||
      typeof value === "string" ||
      typeof value === "number" ||
      typeof value === "boolean" ||
      typeof value === "undefined" ||
      typeof value === "function" ||
      value instanceof RegExp
    )
  }

  private isObject(value: any): boolean {
    return (
      value !== null &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      !(value instanceof RegExp) &&
      !(value instanceof Date)
    )
  }

  private areEqual(left: any, right: any): boolean {
    if (left === right) {
      return true
    }

    if (typeof left === "function" && typeof right === "function") {
      return left.toString() === right.toString()
    }

    if (left instanceof RegExp && right instanceof RegExp) {
      return left.toString() === right.toString()
    }

    if (left instanceof Date && right instanceof Date) {
      return left.getTime() === right.getTime()
    }

    return false
  }

  private getValueType(value: any): string {
    if (value === null) return "null"
    if (value === undefined) return "undefined"
    if (Array.isArray(value)) return "array"
    if (value instanceof RegExp) return "regexp"
    if (value instanceof Date) return "date"
    if (typeof value === "function") return "function"
    return typeof value
  }

  private serializeValue(value: any): any {
    if (value === undefined) {
      return undefined
    }

    if (typeof value === "function") {
      const fnStr = value.toString()
      if (fnStr.length > 200) {
        return `[Function: ${value.name || "anonymous"}] (${fnStr.length} chars)`
      }
      return `[Function: ${value.name || "anonymous"}]`
    }

    if (value instanceof RegExp) {
      return value.toString()
    }

    if (value instanceof Date) {
      return value.toISOString()
    }

    if (Array.isArray(value)) {
      return `[Array(${value.length})]`
    }

    if (this.isObject(value)) {
      const keys = Object.keys(value)
      return `[Object: ${keys.length} keys]`
    }

    return value
  }

  private calculateSummary(): DiffResult["summary"] {
    const summary: {
      totalChanges: number
      added: number
      removed: number
      changed: number
      unchanged?: number
    } = {
      totalChanges: 0,
      added: 0,
      removed: 0,
      changed: 0,
      unchanged: 0
    }

    for (const entry of this.entries) {
      if (entry.operation === "added") {
        summary.added += 1
      } else if (entry.operation === "removed") {
        summary.removed += 1
      } else if (entry.operation === "changed") {
        summary.changed += 1
      } else if (entry.operation === "unchanged") {
        summary.unchanged = (summary.unchanged || 0) + 1
      }

      if (entry.operation !== "unchanged") {
        summary.totalChanges += 1
      }
    }

    if (!this.options.includeUnchanged) {
      delete summary.unchanged
    }

    return summary
  }
}
