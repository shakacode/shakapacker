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
  const baseMessage = `Failed to ${operation} file at path '${filePath}'`
  const errorDetails = details ? ` - ${details}` : ''
  const suggestion = operation === 'read' 
    ? ' (check if file exists and permissions are correct)'
    : operation === 'write'
    ? ' (check write permissions and disk space)'
    : ' (check permissions)'
  return new Error(`${baseMessage}${errorDetails}${suggestion}`)
}

/**
 * Safely gets error message from unknown error type
 */
export function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    // Include stack trace for better debugging in development
    const isDev = process.env.NODE_ENV === 'development'
    return isDev && error.stack ? `${error.message}\n${error.stack}` : error.message
  }
  if (typeof error === 'string') {
    return error
  }
  if (error && typeof error === 'object' && 'message' in error) {
    return String((error as { message: unknown }).message)
  }
  // Provide more context for truly unknown errors
  return `Unknown error occurred (type: ${typeof error}, value: ${JSON.stringify(error)})`
}

/**
 * Type guard for NodeJS errors with errno
 */
export function isNodeError(error: unknown): error is NodeJS.ErrnoException {
  return (
    error instanceof Error &&
    'code' in error &&
    typeof (error as NodeJS.ErrnoException).code === 'string'
  )
}


