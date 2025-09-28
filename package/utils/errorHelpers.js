"use strict";
/**
 * Error handling utilities for consistent error management
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.isFileNotFoundError = isFileNotFoundError;
exports.isModuleNotFoundError = isModuleNotFoundError;
exports.createFileOperationError = createFileOperationError;
exports.getErrorMessage = getErrorMessage;
exports.isNodeError = isNodeError;
/**
 * Checks if an error is a file not found error (ENOENT)
 */
function isFileNotFoundError(error) {
    return (error !== null &&
        typeof error === 'object' &&
        'code' in error &&
        error.code === 'ENOENT');
}
/**
 * Checks if an error is a module not found error
 */
function isModuleNotFoundError(error) {
    return (error !== null &&
        typeof error === 'object' &&
        'code' in error &&
        error.code === 'MODULE_NOT_FOUND');
}
/**
 * Creates a consistent error message for file operations
 */
function createFileOperationError(operation, filePath, details) {
    const baseMessage = `Failed to ${operation} file at path '${filePath}'`;
    const errorDetails = details ? ` - ${details}` : '';
    const suggestion = operation === 'read'
        ? ' (check if file exists and permissions are correct)'
        : operation === 'write'
            ? ' (check write permissions and disk space)'
            : ' (check permissions)';
    return new Error(`${baseMessage}${errorDetails}${suggestion}`);
}
/**
 * Safely gets error message from unknown error type
 */
function getErrorMessage(error) {
    if (error instanceof Error) {
        // Include stack trace for better debugging in development
        const isDev = process.env.NODE_ENV === 'development';
        return isDev && error.stack ? `${error.message}\n${error.stack}` : error.message;
    }
    if (typeof error === 'string') {
        return error;
    }
    if (error && typeof error === 'object' && 'message' in error) {
        return String(error.message);
    }
    // Provide more context for truly unknown errors
    return `Unknown error occurred (type: ${typeof error}, value: ${JSON.stringify(error)})`;
}
/**
 * Type guard for NodeJS errors with errno
 */
function isNodeError(error) {
    return (error instanceof Error &&
        'code' in error &&
        typeof error.code === 'string');
}
// Export as CommonJS for compatibility
module.exports = {
    isFileNotFoundError,
    isModuleNotFoundError,
    createFileOperationError,
    getErrorMessage,
    isNodeError
};
