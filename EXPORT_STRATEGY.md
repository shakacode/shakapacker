# Export Strategy Guide

This document clarifies the export patterns used throughout the Shakapacker codebase and when to use each one.

## Current State (Mixed Strategy)

The codebase intentionally uses a mixed export strategy to maintain CommonJS compatibility while gradually adopting ES6 modules. This is necessary because:

1. **Dynamic requires**: Some modules are loaded dynamically at runtime based on configuration
2. **Legacy compatibility**: Existing consumers may rely on CommonJS patterns
3. **Gradual migration**: We're moving toward ES6 modules without breaking changes

## Export Patterns

### Use `export =` (CommonJS-style)

**When to use:**

- Module is dynamically loaded via `require()` at runtime
- Module needs to be the direct return value of `require()` (not `{ default: ... }`)
- Maintaining backward compatibility with existing CommonJS consumers

**Examples:**

```typescript
// package/rules/webpack.ts
export = [
  raw,
  file,
  css
  // ...
].filter(Boolean)

// package/env.ts
export = {
  isProd,
  isDev,
  isTest
  // ...
}
```

**Why:** These modules are loaded dynamically in `package/environments/base.ts`:

```javascript
const rules = require(rulesPath) // Expects array, not { default: [...] }
```

### Use `export default` (ES6 Default Export)

**When to use:**

- Single default export for ES6 consumers
- Module represents a single configuration or utility
- Not dynamically required at runtime

**Examples:**

```typescript
// Individual rule configs
// package/rules/css.ts
export default getStyleRule("css", "css-loader")

// Configuration objects
// package/environments/base.ts
export default baseConfig

// Utilities with single export
// package/dev_server.ts
export default devServerConfig || {}
```

### Use Named Exports

**When to use:**

- Module provides multiple exports
- Public API with multiple functions/types
- Re-exporting from other modules

**Examples:**

```typescript
// package/index.ts
export {
  chdirCwd,
  chdirApp,
  resetEnv
  // ...
}

// Type definitions
// package/types.ts
export interface WebpackerConfig {
  // ...
}
export type ConfigPath = string | string[]
```

## Import Patterns

### When to use `require()`

**Must use `require()` when:**

1. Importing modules that use `export =`
2. Dynamic imports with runtime path construction
3. Conditional imports based on configuration

**Examples:**

```javascript
// Required because env.ts uses export =
const env = require("./env")

// Dynamic path - cannot use static import
const rulesPath = resolve(__dirname, "rules", `${config.assets_bundler}.js`)
const rules = require(rulesPath)

// Conditional loading
if (moduleExists("css-loader")) {
  const cssLoader = require("css-loader")
}
```

### When to use ES6 imports

**Use ES6 imports for:**

- TypeScript type imports
- Static imports of ES6 modules
- Modules with named exports or export default

**Examples:**

```typescript
import { resolve } from "path"
import type { Configuration } from "webpack"
import baseConfig from "./environments/base"
```

## Migration Path

### Current Issues

- Mixed patterns can be confusing for contributors
- Tests need to know which pattern each module uses
- TypeScript compilation differs based on export pattern

### Future Goal (Major Version)

1. Convert all `export =` to `export default` or named exports
2. Replace all `require()` with ES6 imports (including dynamic imports)
3. Provide codemod for automated migration
4. See issue #708 for tracking

## Quick Reference

| Module                            | Export Pattern   | Import Pattern                  | Reason                              |
| --------------------------------- | ---------------- | ------------------------------- | ----------------------------------- |
| `package/env.ts`                  | `export =`       | `require()`                     | Multiple files use CommonJS require |
| `package/rules/webpack.ts`        | `export =`       | `require()`                     | Dynamic loading in base.ts          |
| `package/rules/rspack.ts`         | `export =`       | `require()`                     | Dynamic loading in base.ts          |
| `package/rules/*.ts` (individual) | `export default` | `import` or `require().default` | Single config export                |
| `package/environments/*.ts`       | `export default` | `import` or `require().default` | Single config export                |
| `package/index.ts`                | Named exports    | `import { }`                    | Public API                          |
| `package/types.ts`                | Named exports    | `import type { }`               | Type definitions                    |

## Testing Considerations

When testing modules:

- `export =` modules: Use `require()` directly
- `export default` modules: Use `require().default` or ES6 import
- Named export modules: Use `require().exportName` or ES6 import

## Related Documentation

- [ESLINT_TECHNICAL_DEBT.md](./ESLINT_TECHNICAL_DEBT.md) - ESLint issues including module system
- Issue #708 - Module System: Modernize to ES6 modules with codemod
