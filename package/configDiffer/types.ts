export type DiffOperation = "added" | "removed" | "changed" | "unchanged"

export interface DiffPath {
  path: string[]
  humanPath: string
}

export interface DiffEntry {
  operation: DiffOperation
  path: DiffPath
  oldValue?: any
  newValue?: any
  valueType?: string
}

export interface DiffResult {
  summary: {
    totalChanges: number
    added: number
    removed: number
    changed: number
    unchanged?: number
  }
  entries: DiffEntry[]
  metadata: {
    comparedAt: string
    leftFile?: string
    rightFile?: string
    leftMetadata?: any
    rightMetadata?: any
  }
}

export interface DiffOptions {
  includeUnchanged?: boolean
  maxDepth?: number | null
  ignoreKeys?: string[]
  ignorePaths?: string[]
  format?: "json" | "yaml" | "summary" | "detailed"
  normalizePaths?: boolean
  pathSeparator?: string
}

export interface NormalizedConfig {
  original: any
  normalized: any
  basePath?: string
}
