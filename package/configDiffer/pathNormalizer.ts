import { homedir } from "os"
import { posix as posixPath, win32 as win32Path } from "path"
import { NormalizedConfig } from "./types"

type PathFlavor = "posix" | "win32"

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

    const normalizedPath = this.expandHomePath(str)
    const normalizedBasePath = this.expandHomePath(this.basePath)

    const baseFlavor = this.detectPathFlavor(normalizedBasePath)
    const inputFlavor = this.detectPathFlavor(normalizedPath)
    const inputIsAbsolute = PathNormalizer.isAbsolutePath(normalizedPath)

    if (inputIsAbsolute && inputFlavor !== baseFlavor) {
      return str
    }

    if (
      !inputIsAbsolute &&
      normalizedPath.includes("\\") &&
      baseFlavor !== "win32"
    ) {
      return str
    }

    const effectiveFlavor = inputIsAbsolute ? inputFlavor : baseFlavor
    const pathModule = this.getPathModule(effectiveFlavor)
    const absolutePath = inputIsAbsolute
      ? normalizedPath
      : pathModule.resolve(normalizedBasePath, normalizedPath)

    const relativePath = pathModule.relative(normalizedBasePath, absolutePath)

    if (relativePath === "") {
      return "./"
    }

    if (relativePath && !relativePath.startsWith("..")) {
      return `./${relativePath.split(pathModule.sep).join("/")}`
    }

    return str
  }

  private looksLikePath(str: string): boolean {
    if (str.length < 2) {
      return false
    }

    // Exclude URLs with schemes (http://, https://, file://, webpack://, etc.)
    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(str)) {
      return false
    }

    // Exclude module specifiers starting with @
    if (str.startsWith("@")) {
      return false
    }

    // Check for actual filesystem paths
    // Absolute POSIX paths
    if (str.startsWith("/") || str.startsWith("\\")) {
      return true
    }

    // Relative paths
    if (
      str.startsWith("./") ||
      str.startsWith(".\\") ||
      str.startsWith("../") ||
      str.startsWith("..\\")
    ) {
      return true
    }

    // Home directory paths
    if (str === "~" || str.startsWith("~/") || str.startsWith("~\\")) {
      return true
    }

    // Windows drive paths (C:\, D:\, C:/, D:/, etc.)
    if (/^[A-Za-z]:[\\/]/.test(str)) {
      return true
    }

    return false
  }

  private isPlainObject(value: unknown): value is Record<string, unknown> {
    return PathNormalizer.isPlainObjectValue(value)
  }

  static detectBasePath(config: any): string | undefined {
    const pathsByFlavor: Record<PathFlavor, string[]> = {
      posix: [],
      win32: []
    }

    const extractPaths = (value: any): void => {
      if (typeof value === "string") {
        const expandedPath = this.expandHomePath(value)
        if (this.isAbsolutePath(expandedPath)) {
          const flavor = this.detectPathFlavor(expandedPath)
          pathsByFlavor[flavor].push(expandedPath)
        }
      } else if (Array.isArray(value)) {
        value.forEach(extractPaths)
      } else if (this.isPlainObjectValue(value)) {
        Object.values(value).forEach(extractPaths)
      }
    }

    extractPaths(config)

    const preferredFlavor: PathFlavor =
      pathsByFlavor.posix.length >= pathsByFlavor.win32.length
        ? "posix"
        : "win32"
    const paths = pathsByFlavor[preferredFlavor]

    if (paths.length === 0) {
      return undefined
    }

    const commonPrefix = this.findCommonPrefix(paths, preferredFlavor)
    return commonPrefix || undefined
  }

  private static findCommonPrefix(paths: string[], flavor: PathFlavor): string {
    if (paths.length === 0) {
      return ""
    }

    const pathModule = this.getPathModule(flavor)
    let prefix = pathModule.dirname(paths[0])

    for (const candidatePath of paths.slice(1)) {
      while (
        prefix &&
        !this.isWithinBasePath(pathModule, prefix, candidatePath)
      ) {
        const parent = pathModule.dirname(prefix)
        if (parent === prefix) {
          return ""
        }
        prefix = parent
      }

      if (!prefix) {
        return ""
      }
    }

    return prefix
  }

  private static isWithinBasePath(
    pathModule: typeof posixPath,
    basePath: string,
    candidatePath: string
  ): boolean {
    const relativePath = pathModule.relative(basePath, candidatePath)
    return (
      relativePath === "" ||
      (!relativePath.startsWith("..") && !pathModule.isAbsolute(relativePath))
    )
  }

  private getPathModule(flavor: PathFlavor): typeof posixPath {
    return PathNormalizer.getPathModule(flavor)
  }

  private static getPathModule(flavor: PathFlavor): typeof posixPath {
    return flavor === "win32" ? win32Path : posixPath
  }

  private detectPathFlavor(value: string): PathFlavor {
    return PathNormalizer.detectPathFlavor(value)
  }

  private static detectPathFlavor(value: string): PathFlavor {
    if (/^[A-Za-z]:[\\/]/.test(value) || value.startsWith("\\\\")) {
      return "win32"
    }

    if (value.includes("\\")) {
      return "win32"
    }

    return "posix"
  }

  private expandHomePath(value: string): string {
    return PathNormalizer.expandHomePath(value)
  }

  private static expandHomePath(value: string): string {
    if (value === "~") {
      return homedir()
    }

    if (value.startsWith("~/") || value.startsWith("~\\")) {
      const home = homedir()
      const homeFlavor = this.detectPathFlavor(home)
      const pathModule = this.getPathModule(homeFlavor)
      const relativeHomePath = value.slice(2).replace(/[\\/]+/g, pathModule.sep)
      return pathModule.join(home, relativeHomePath)
    }

    return value
  }

  private static isAbsolutePath(value: string): boolean {
    return posixPath.isAbsolute(value) || win32Path.isAbsolute(value)
  }

  private static isPlainObjectValue(
    value: unknown
  ): value is Record<string, unknown> {
    if (
      value === null ||
      typeof value !== "object" ||
      Array.isArray(value) ||
      value instanceof Date ||
      value instanceof RegExp
    ) {
      return false
    }

    const prototype = Object.getPrototypeOf(value)
    return prototype === Object.prototype || prototype === null
  }
}
