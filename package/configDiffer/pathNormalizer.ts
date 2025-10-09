import { resolve, isAbsolute, relative, sep } from "path"
import { NormalizedConfig } from "./types"

export class PathNormalizer {
  private basePath: string

  constructor(basePath?: string) {
    this.basePath = basePath || process.cwd()
  }

  normalize(config: any): NormalizedConfig {
    return {
      original: config,
      normalized: this.normalizeValue(config),
      basePath: this.basePath
    }
  }

  private normalizeValue(value: any): any {
    if (typeof value === "string") {
      return this.normalizePath(value)
    }

    if (Array.isArray(value)) {
      return value.map((item) => this.normalizeValue(item))
    }

    if (this.isPlainObject(value)) {
      const normalized: Record<string, any> = {}
      for (const key in value) {
        if (Object.prototype.hasOwnProperty.call(value, key)) {
          normalized[key] = this.normalizeValue(value[key])
        }
      }
      return normalized
    }

    return value
  }

  private normalizePath(str: string): string {
    if (!this.looksLikePath(str)) {
      return str
    }

    const absolutePath = isAbsolute(str) ? str : resolve(this.basePath, str)

    const relativePath = relative(this.basePath, absolutePath)

    if (relativePath && !relativePath.startsWith("..")) {
      return "./" + relativePath.split(sep).join("/")
    }

    return str
  }

  private looksLikePath(str: string): boolean {
    if (str.length < 2) {
      return false
    }

    const pathIndicators = [
      "/",
      "\\",
      "./",
      ".\\",
      "../",
      "..\\",
      "~/",
      "C:",
      "D:"
    ]

    return pathIndicators.some((indicator) => str.includes(indicator))
  }

  private isPlainObject(value: any): boolean {
    if (value === null || typeof value !== "object") {
      return false
    }

    if (Array.isArray(value)) {
      return false
    }

    if (value instanceof Date || value instanceof RegExp) {
      return false
    }

    if (typeof value === "function") {
      return false
    }

    return true
  }

  static detectBasePath(config: any): string | undefined {
    const paths: string[] = []

    const extractPaths = (value: any): void => {
      if (typeof value === "string" && isAbsolute(value)) {
        paths.push(value)
      } else if (Array.isArray(value)) {
        value.forEach(extractPaths)
      } else if (value && typeof value === "object") {
        Object.values(value).forEach(extractPaths)
      }
    }

    extractPaths(config)

    if (paths.length === 0) {
      return undefined
    }

    const commonPrefix = this.findCommonPrefix(paths)
    return commonPrefix || undefined
  }

  private static findCommonPrefix(paths: string[]): string {
    if (paths.length === 0) {
      return ""
    }

    if (paths.length === 1) {
      return paths[0].split(sep).slice(0, -1).join(sep)
    }

    const splitPaths = paths.map((p) => p.split(sep))
    let prefix: string[] = []

    for (let i = 0; i < splitPaths[0].length; i++) {
      const segment = splitPaths[0][i]
      if (splitPaths.every((p) => p[i] === segment)) {
        prefix.push(segment)
      } else {
        break
      }
    }

    return prefix.join(sep)
  }
}
