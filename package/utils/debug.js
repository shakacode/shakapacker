/**
 * Debug utility for Shakapacker
 * Provides conditional logging based on environment variables
 */

const isDebugMode = () => {
  // Explicitly check for debug mode being enabled
  if (process.env.SHAKAPACKER_DEBUG === "false") {
    return false
  }

  return (
    process.env.SHAKAPACKER_DEBUG === "true" ||
    process.env.DEBUG_SHAKAPACKER === "true"
  )
}

const debug = (message, ...args) => {
  if (isDebugMode()) {
    console.log(`[Shakapacker] ${message}`, ...args)
  }
}

const warn = (message, ...args) => {
  console.warn(`[Shakapacker] WARNING: ${message}`, ...args)
}

const error = (message, ...args) => {
  console.error(`[Shakapacker] ERROR: ${message}`, ...args)
}

const info = (message, ...args) => {
  if (isDebugMode()) {
    console.info(`[Shakapacker] INFO: ${message}`, ...args)
  }
}

module.exports = {
  debug,
  warn,
  error,
  info,
  isDebugMode
}