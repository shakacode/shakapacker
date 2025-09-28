# TypeScript Migration Guide

## Overview
This guide explains the TypeScript migration for Shakapacker and how it affects users.

## No Breaking Changes
**The TypeScript migration introduces NO breaking changes.** Here's why:

1. **JavaScript Output Unchanged**: TypeScript files compile to the same JavaScript that was there before
2. **CommonJS Maintained**: We continue using CommonJS (`module.exports`) for compatibility
3. **API Surface Unchanged**: All exports and imports work exactly the same way
4. **Type Definitions Optional**: Users can continue using JavaScript - TypeScript is not required

## Migration Not Required
**Users do NOT need to migrate their configurations to TypeScript.** Both JavaScript and TypeScript configurations work:

### JavaScript Config (Still Works)
```javascript
// webpack.config.js
const { generateWebpackConfig } = require("shakapacker")
const customConfig = require("./custom-config")

module.exports = generateWebpackConfig(customConfig)
```

### TypeScript Config (Now Supported)
```typescript
// webpack.config.ts
import { generateWebpackConfig, Config } from "shakapacker"
import { Configuration } from "webpack"
import customConfig from "./custom-config"

const config: Configuration = generateWebpackConfig(customConfig)
export default config
```

## Example Configurations

### webpack.config.ts
```typescript
import { generateWebpackConfig } from "shakapacker"
import type { Configuration } from "webpack"

const customConfig: Configuration = {
  resolve: {
    extensions: [".tsx", ".ts", ".jsx", ".js"]
  },
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: "ts-loader",
        exclude: /node_modules/
      }
    ]
  }
}

const config = generateWebpackConfig(customConfig)
export default config
```

### rspack.config.ts
```typescript
import { generateRspackConfig } from "shakapacker/rspack"
import type { RspackOptions } from "@rspack/core"

const customConfig: RspackOptions = {
  resolve: {
    extensions: [".tsx", ".ts", ".jsx", ".js"]
  },
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: {
          loader: "builtin:swc-loader",
          options: {
            jsc: {
              parser: {
                syntax: "typescript",
                tsx: true
              }
            }
          }
        },
        exclude: /node_modules/
      }
    ]
  }
}

const config = generateRspackConfig(customConfig)
export default config
```

## Using Type Definitions
Even if you're using JavaScript, you can benefit from type definitions:

```javascript
// webpack.config.js with JSDoc types
const { generateWebpackConfig } = require("shakapacker")

/**
 * @type {import('webpack').Configuration}
 */
const customConfig = {
  // Your IDE will now provide autocomplete!
  resolve: {
    extensions: [".tsx", ".ts", ".jsx", ".js"]
  }
}

module.exports = generateWebpackConfig(customConfig)
```

## Migration Phases
The TypeScript migration is happening in phases:

| Phase | Status | Description |
|-------|--------|-------------|
| 1 | ✅ Complete | Type definitions (PR #602) |
| 2 | ✅ Complete | Core modules (This PR) |
| 3 | 🔄 Planned | Environment & Build System |
| 4 | 🔄 Planned | Rules & Loaders |
| 5 | 🔄 Planned | Framework-Specific Modules |
| 6 | 🔄 Planned | Remaining Utilities |

## Verification of No Breaking Changes

### How We Ensure Compatibility
1. **Test Suite**: All existing tests pass without modification
2. **JavaScript Output**: TypeScript compiles to equivalent JavaScript
3. **API Contract**: All public exports remain the same
4. **CommonJS Format**: Continues using `module.exports` and `require()`

### What Changes Under the Hood
- Source files now in TypeScript (`.ts`)
- Type definitions automatically generated
- Better IDE support and autocomplete
- Type checking during development

### What Doesn't Change
- Runtime behavior
- API surface
- Module format (CommonJS)
- Configuration format
- Webpack/Rspack integration

## Benefits for Users

### TypeScript Users
- Full type safety
- Better autocomplete
- Catch configuration errors at compile time
- Improved developer experience

### JavaScript Users
- No changes required
- Optional type hints via JSDoc
- Better IDE support even in JS files
- No migration needed

## Version Compatibility

### Should This Be in v9?
**Yes, this is perfect for v9:**

1. **No Breaking Changes**: Safe to include in any release
2. **Progressive Enhancement**: Adds value without requiring changes
3. **Future-Ready**: Sets foundation for further improvements
4. **Backward Compatible**: All v8 configs continue working

### Incremental Adoption Order
The PR order for incremental adoption:

1. **PR #602** - Type definitions (merged)
2. **PR #608** - Core modules (this PR) 
3. Environment & Build System
4. Rules & Loaders
5. Framework-Specific Modules
6. Utilities

Each PR is:
- Self-contained
- Backward compatible
- Independently testable
- Small and reviewable

## FAQ

### Do I need to convert my config to TypeScript?
No. JavaScript configs continue to work perfectly.

### Will this affect my build times?
No. TypeScript compilation happens during Shakapacker development, not in your project.

### Can I use TypeScript types in my JavaScript?
Yes! Use JSDoc comments to get type hints in JavaScript files.

### Is TypeScript now a required dependency?
No. TypeScript is only a development dependency of Shakapacker itself.

### What if I find a type definition error?
Please report it as an issue. Type definitions can be fixed without breaking changes.

## Conclusion
The TypeScript migration is designed to be completely transparent to users while providing optional benefits for those who want them. There are no breaking changes, no required migrations, and full backward compatibility is maintained.
