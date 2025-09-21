/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

// Legacy compatibility wrapper
// For backward compatibility, default to webpack exports
// New usage should prefer explicit imports:
//   require('shakapacker/webpack') or require('shakapacker/rspack')

const webpackExports = require("./webpack")

// Re-export all webpack functionality for backward compatibility
module.exports = {
  ...webpackExports,
  // Explicit re-export of the main function for clarity
  generateWebpackConfig: webpackExports.generateWebpackConfig
}
