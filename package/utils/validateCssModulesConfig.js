/* eslint global-require: 0 */
const { warn } = require("./debug")

/**
 * Validates CSS modules configuration and warns about potential issues
 * with v9 defaults or conflicting settings.
 */
const validateCssModulesConfig = (cssLoaderOptions) => {
  // Skip validation in production by default for performance
  if (process.env.NODE_ENV === 'production' && process.env.SHAKAPACKER_VALIDATE_CSS_MODULES !== 'true') {
    return
  }

  if (!cssLoaderOptions || !cssLoaderOptions.modules) {
    return
  }

  const { modules } = cssLoaderOptions

  // Check for conflicting namedExport and esModule settings
  if (modules.namedExport === true && modules.esModule === false) {
    warn(
      "⚠️  CSS Modules Configuration Warning:\n" +
      "    namedExport: true with esModule: false may cause issues.\n" +
      "    Consider setting esModule: true or removing it (defaults to true)."
    )
  }

  // Check for v8-style configuration with v9
  if (modules.namedExport === false) {
    warn(
      "ℹ️  CSS Modules Configuration Note:\n" +
      "    You are using namedExport: false (v8 behavior).\n" +
      "    Shakapacker v9 defaults to namedExport: true for better tree-shaking.\n" +
      "    See docs/css-modules-export-mode.md for migration instructions."
    )
  }

  // Check for inconsistent exportLocalsConvention with namedExport
  if (modules.namedExport === true && modules.exportLocalsConvention === "asIs") {
    warn(
      "⚠️  CSS Modules Configuration Warning:\n" +
      "    Using namedExport: true with exportLocalsConvention: 'asIs' may cause issues\n" +
      "    with kebab-case class names (e.g., 'my-button').\n" +
      "    Consider using exportLocalsConvention: 'camelCase' (v9 default)."
    )
  }

  // Check for deprecated localIdentName pattern
  if (modules.localIdentName && modules.localIdentName.includes("[hash:base64]")) {
    warn(
      "⚠️  CSS Modules Configuration Warning:\n" +
      "    [hash:base64] is deprecated in css-loader v6+.\n" +
      "    Use [hash] instead for better compatibility."
    )
  }

  // Check for potential TypeScript issues
  if (modules.namedExport === true && process.env.SHAKAPACKER_ASSET_COMPILER_TYPESCRIPT === "true") {
    warn(
      "ℹ️  TypeScript CSS Modules Note:\n" +
      "    With namedExport: true, TypeScript projects should use:\n" +
      "    import * as styles from './styles.module.css'\n" +
      "    instead of: import styles from './styles.module.css'\n" +
      "    See docs/css-modules-export-mode.md for TypeScript setup."
    )
  }

  // Check for auto: true with getLocalIdent (potential conflict)
  if (modules.auto === true && modules.getLocalIdent) {
    warn(
      "⚠️  CSS Modules Configuration Warning:\n" +
      "    Using both 'auto: true' and 'getLocalIdent' may cause conflicts.\n" +
      "    The 'auto' option determines which files are treated as CSS modules."
    )
  }
}

module.exports = { validateCssModulesConfig }