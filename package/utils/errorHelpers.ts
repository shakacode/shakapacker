/**
 * Error handling utilities for consistent error management
 */

/**
 * Checks if an error is a file not found error (ENOENT)
 */
export function isFileNotFoundError(error: unknown): boolean {
  return (
    error !== null &&
    typeof error === 'object' &&
    'code' in error &&
    (error as NodeJS.ErrnoException).code === 'ENOENT'
  )
}

/**
 * Checks if an error is a module not found error
 */
export function isModuleNotFoundError(error: unknown): boolean {
  return (
    error !== null &&
    typeof error === 'object' &&
    'code' in error &&
    (error as NodeJS.ErrnoException).code === 'MODULE_NOT_FOUND'
  )
}

/**
 * Creates a consistent error message for file operations
 */
export function createFileOperationError(
  operation: 'read' | 'write' | 'delete',
  filePath: string,
  details?: string
): Error {
  const baseMessage = `Failed to ${operation} file: ${filePath}`
  return new Error(details ? `${baseMessage} - ${details}` : baseMessage)
}

/**
 * Safely gets error message from unknown error type
 */
export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message
  }
  if (typeof error === 'string') {
    return error
  }
  if (error && typeof error === 'object' && 'message' in error) {
    return String((error as { message: unknown }).message)
  }
  return 'Unknown error'
}

/**
 * Type guard for NodeJS errors with errno
 */
export function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return (
    error instanceof Error &&
    'code' in error &&
    typeof (error as any).code === 'string'
  )
}

// Export as CommonJS for compatibility
module.exports = {
  isFileNotFoundError,
  isModuleNotFoundError,
  createFileOperationError,
  getErrorMessage,
  isNodeError
}
