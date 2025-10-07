import * as path from "path"
import * as fs from "fs"

/**
 * Security utilities for validating and sanitizing file paths
 */

/**
 * Validates a path doesn't contain traversal patterns
 */
export function isPathTraversalSafe(inputPath: string): boolean {
  // Check for common traversal patterns
  // Null byte short-circuit (avoid regex with control chars)
  if (inputPath.includes("\0")) return false

  const dangerousPatterns = [
    /\.\.[/\\]/, // ../ or ..\
    /^\//, // POSIX absolute
    /^[A-Za-z]:[/\\]/, // Windows absolute (C:\ or C:/)
    /^\\\\/, // Windows UNC (\\server\share)
    /~[/\\]/, // Home directory expansion
    /%2e%2e/i // URL encoded traversal
  ]

  return !dangerousPatterns.some((pattern) => pattern.test(inputPath))
}

/**
 * Resolves and validates a path within a base directory
 * Prevents directory traversal attacks by ensuring the resolved path
 * stays within the base directory
 */
export function safeResolvePath(basePath: string, userPath: string): string {
  // Normalize the base path
  const normalizedBase = path.resolve(basePath)

  // Resolve the user path relative to base
  const resolved = path.resolve(normalizedBase, userPath)

  // Ensure the resolved path is within the base directory
  if (
    !resolved.startsWith(normalizedBase + path.sep) &&
    resolved !== normalizedBase
  ) {
    throw new Error(
      `[SHAKAPACKER SECURITY] Path traversal attempt detected.\n` +
        `Requested path would resolve outside of allowed directory.\n` +
        `Base: ${normalizedBase}\n` +
        `Attempted: ${userPath}\n` +
        `Resolved to: ${resolved}`
    )
  }

  return resolved
}

/**
 * Validates that a path exists and is accessible
 */
export function validatePathExists(filePath: string): boolean {
  try {
    fs.accessSync(filePath, fs.constants.R_OK)
    return true
  } catch {
    return false
  }
}

/**
 * Validates an array of paths for security issues
 */
export function validatePaths(paths: string[], basePath: string): string[] {
  const validatedPaths: string[] = []

  paths.forEach((userPath) => {
    if (!isPathTraversalSafe(userPath)) {
      // eslint-disable-next-line no-console
      console.warn(
        `[SHAKAPACKER WARNING] Skipping potentially unsafe path: ${userPath})`
      )
      return
    }

    try {
      const safePath = safeResolvePath(basePath, userPath)
      validatedPaths.push(safePath)
    } catch (_error) {
      // eslint-disable-next-line no-console
      console.warn(
        `[SHAKAPACKER WARNING] Invalid path configuration: ${userPath}\n` +
          `Error: ${_error instanceof Error ? _error.message : String(_error)}`
      )
    }
  })

  return validatedPaths
}

/**
 * Sanitizes environment variable values to prevent injection
 */
export function sanitizeEnvValue(
  value: string | undefined
): string | undefined {
  if (!value) return value

  // Remove control characters and null bytes
  // Filter by character code to avoid control character regex (Biome compliance)
  const sanitized = value
    .split("")
    .filter((char) => {
      const code = char.charCodeAt(0)
      // Keep chars with code > 31 (after control chars) and not 127 (DEL)
      return code > 31 && code !== 127
    })
    .join("")

  // Warn if sanitization changed the value
  if (sanitized !== value) {
    // eslint-disable-next-line no-console
    console.warn(
      `[SHAKAPACKER SECURITY] Environment variable value contained control characters that were removed`
    )
  }

  return sanitized
}

/**
 * Validates a port number or string
 */
export function validatePort(port: unknown): boolean {
  if (port === "auto") return true

  if (typeof port === "number") {
    return port > 0 && port <= 65535 && Number.isInteger(port)
  }

  if (typeof port === "string") {
    // First check if the string contains only digits
    if (!/^\d+$/.test(port)) {
      return false
    }
    // Only then parse and validate range
    const num = parseInt(port, 10)
    return num > 0 && num <= 65535
  }

  return false
}
