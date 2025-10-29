import { relative, isAbsolute } from "path"
import { ConfigMetadata } from "./types"
import { getDocForKey } from "./configDocs"

/**
 * Serializes webpack/rspack config to YAML format with optional inline documentation.
 * Handles functions, RegExp, and special objects that don't serialize well to standard YAML.
 */
export class YamlSerializer {
  private annotate: boolean

  private appRoot: string

  constructor(options: { annotate: boolean; appRoot: string }) {
    this.annotate = options.annotate
    this.appRoot = options.appRoot
  }

  /**
   * Serialize a config object to YAML string with metadata header
   */
  serialize(config: any, metadata: ConfigMetadata): string {
    const output: string[] = []

    // Add metadata header
    output.push(YamlSerializer.createHeader(metadata))
    output.push("")

    // Serialize the config
    output.push(this.serializeValue(config, 0, ""))

    return output.join("\n")
  }

  private static createHeader(metadata: ConfigMetadata): string {
    const lines: string[] = []
    lines.push(`# ${"=".repeat(77)}`)
    lines.push("# Webpack/Rspack Configuration Export")
    lines.push(`# Generated: ${metadata.exportedAt}`)
    lines.push(`# Environment: ${metadata.environment}`)
    lines.push(`# Bundler: ${metadata.bundler}`)
    lines.push(`# Config Type: ${metadata.configType}`)
    if (metadata.configCount > 1) {
      lines.push(`# Total Configs: ${metadata.configCount}`)
    }
    lines.push(`# ${"=".repeat(77)}`)
    return lines.join("\n")
  }

  private serializeValue(value: any, indent: number, keyPath: string): string {
    if (value === null || value === undefined) {
      return "null"
    }

    if (typeof value === "boolean") {
      return value.toString()
    }

    if (typeof value === "number") {
      return value.toString()
    }

    if (typeof value === "string") {
      return this.serializeString(value, indent)
    }

    if (typeof value === "function") {
      return this.serializeFunction(value)
    }

    if (value instanceof RegExp) {
      return this.serializeString(value.toString())
    }

    if (Array.isArray(value)) {
      return this.serializeArray(value, indent, keyPath)
    }

    if (typeof value === "object") {
      return this.serializeObject(value, indent, keyPath)
    }

    return String(value)
  }

  private serializeString(str: string, indent: number = 0): string {
    // Make absolute paths relative for cleaner output
    const cleaned = this.makePathRelative(str)

    // Handle multiline strings
    if (cleaned.includes("\n")) {
      const lines = cleaned.split("\n")
      const lineIndent = " ".repeat(indent + 2)
      return `|\n${lines.map((line) => lineIndent + line).join("\n")}`
    }

    // Escape strings that need quoting
    if (
      cleaned.includes(":") ||
      cleaned.includes("#") ||
      cleaned.includes("'") ||
      cleaned.includes('"') ||
      cleaned.startsWith(" ") ||
      cleaned.endsWith(" ")
    ) {
      // Escape backslashes first, then quotes to avoid double-escaping
      return `"${cleaned.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`
    }

    return cleaned
  }

  private serializeFunction(fn: Function): string {
    // Get function source code
    const source = fn.toString()

    // Pretty-print function: maintain readable formatting
    const lines = source.split("\n")

    // For very long functions, truncate
    const maxLines = 50
    const truncated = lines.length > maxLines
    const displayLines = truncated ? lines.slice(0, maxLines) : lines

    // Clean up indentation while preserving structure
    const minIndent = Math.min(
      ...displayLines
        .filter((l) => l.trim().length > 0)
        .map((l) => l.match(/^\s*/)?.[0].length || 0)
    )

    const formatted =
      displayLines.map((line) => line.substring(minIndent)).join("\n") +
      (truncated ? "\n..." : "")

    // Use serializeString to properly handle multiline
    return this.serializeString(formatted)
  }

  private serializeArray(arr: any[], indent: number, keyPath: string): string {
    if (arr.length === 0) {
      return "[]"
    }

    const lines: string[] = []
    const itemIndent = " ".repeat(indent + 2)
    const contentIndent = " ".repeat(indent + 4)

    arr.forEach((item, index) => {
      const itemPath = `${keyPath}[${index}]`

      // Check if this is a plugin object and add its name as a comment
      const pluginName = YamlSerializer.getConstructorName(item)
      const isPlugin = pluginName && /(^|\.)plugins\[\d+\]/.test(itemPath)
      const isEmpty =
        typeof item === "object" &&
        item !== null &&
        !Array.isArray(item) &&
        Object.keys(item).length === 0

      // For non-empty plugins, add comment before the plugin
      // For empty plugins, the name will be shown inline
      if (isPlugin && !isEmpty) {
        lines.push(`${itemIndent}# ${pluginName}`)
      }

      const serialized = this.serializeValue(item, indent + 4, itemPath)

      // Add documentation for array items if available
      if (this.annotate) {
        const doc = getDocForKey(itemPath)
        if (doc) {
          lines.push(`${itemIndent}# ${doc}`)
        }
      }

      if (typeof item === "object" && !Array.isArray(item) && item !== null) {
        // For objects in arrays, emit marker on its own line and indent content
        lines.push(`${itemIndent}-`)
        const nonEmptyLines = serialized
          .split("\n")
          .filter((line: string) => line.trim().length > 0)
        // Compute minimum leading whitespace to preserve relative indentation
        const minIndent = Math.min(
          ...nonEmptyLines.map(
            (line: string) => line.match(/^\s*/)?.[0].length || 0
          )
        )
        nonEmptyLines.forEach((line: string) => {
          // Remove only the common indent, preserving relative indentation
          lines.push(contentIndent + line.substring(minIndent))
        })
      } else if (serialized.includes("\n")) {
        // For multiline values, emit marker on its own line and indent content
        lines.push(`${itemIndent}-`)
        const nonEmptyLines = serialized
          .split("\n")
          .filter((line: string) => line.trim().length > 0)
        // Compute minimum leading whitespace to preserve relative indentation
        const minIndent = Math.min(
          ...nonEmptyLines.map(
            (line: string) => line.match(/^\s*/)?.[0].length || 0
          )
        )
        nonEmptyLines.forEach((line: string) => {
          // Remove only the common indent, preserving relative indentation
          lines.push(contentIndent + line.substring(minIndent))
        })
      } else {
        // For simple values, keep on same line
        lines.push(`${itemIndent}- ${serialized}`)
      }
    })

    return `\n${lines.join("\n")}`
  }

  private serializeObject(obj: any, indent: number, keyPath: string): string {
    const keys = Object.keys(obj)
    const constructorName = YamlSerializer.getConstructorName(obj)

    // For empty objects, show constructor name if available
    if (keys.length === 0) {
      if (constructorName) {
        return `{} # ${constructorName}`
      }
      return "{}"
    }

    const lines: string[] = []
    const keyIndent = " ".repeat(indent)
    const valueIndent = " ".repeat(indent + 2)

    keys.forEach((key) => {
      const value = obj[key]
      const fullKeyPath = keyPath ? `${keyPath}.${key}` : key

      // Add documentation comment if available and annotation is enabled
      if (this.annotate) {
        const doc = getDocForKey(fullKeyPath)
        if (doc) {
          lines.push(`${keyIndent}# ${doc}`)
        }
      }

      // Handle multiline strings specially with block scalar
      if (typeof value === "string" && value.includes("\n")) {
        lines.push(`${keyIndent}${key}: |`)
        for (const line of value.split("\n")) {
          lines.push(`${valueIndent}${line}`)
        }
      } else if (
        typeof value === "object" &&
        value !== null &&
        !Array.isArray(value)
      ) {
        if (Object.keys(value).length === 0) {
          lines.push(`${keyIndent}${key}: {}`)
        } else {
          lines.push(`${keyIndent}${key}:`)
          const nestedLines = this.serializeObject(
            value,
            indent + 2,
            fullKeyPath
          )
          lines.push(nestedLines)
        }
      } else if (Array.isArray(value)) {
        if (value.length === 0) {
          lines.push(`${keyIndent}${key}: []`)
        } else {
          lines.push(`${keyIndent}${key}:`)
          const arrayLines = this.serializeArray(value, indent + 2, fullKeyPath)
          lines.push(arrayLines)
        }
      } else {
        const serialized = this.serializeValue(value, indent + 2, fullKeyPath)
        lines.push(`${keyIndent}${key}: ${serialized}`)
      }
    })

    return lines.join("\n")
  }

  private makePathRelative(str: string): string {
    if (typeof str !== "string") return str
    if (!isAbsolute(str)) return str

    // Convert absolute paths to relative paths using path.relative
    const rel = relative(this.appRoot, str)

    if (rel === "") {
      return "."
    }

    // If path is outside appRoot or already absolute, keep original
    if (rel.startsWith("..") || isAbsolute(rel)) {
      return str
    }

    return `./${rel}`
  }

  /**
   * Extracts the constructor name from an object
   * Returns null for plain objects (Object constructor)
   */
  private static getConstructorName(obj: any): string | null {
    if (!obj || typeof obj !== "object") return null
    if (Array.isArray(obj)) return null

    const constructorName = obj.constructor?.name
    if (!constructorName || constructorName === "Object") return null

    return constructorName
  }
}
