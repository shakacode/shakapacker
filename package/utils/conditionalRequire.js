/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

/**
 * Conditionally require a module, with optional fallback or clear error message
 * @param {string} moduleName - The module to require
 * @param {any} fallback - Optional fallback value if module not found
 * @param {string} bundlerType - Optional bundler type for error message ('webpack', 'rspack')
 * @returns {any} The required module or fallback
 */
const conditionalRequire = (
  moduleName,
  fallback = null,
  bundlerType = null
) => {
  try {
    return require(moduleName)
  } catch (error) {
    if (fallback !== null) {
      return fallback
    }
    const bundlerMsg = bundlerType ? ` for ${bundlerType}` : ""
    throw new Error(
      `${moduleName} is required${bundlerMsg} but not installed. Install with: npm install ${moduleName}`
    )
  }
}

module.exports = { conditionalRequire }
