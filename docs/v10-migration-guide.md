# Shakapacker v10 Migration Guide: ES Module Exports

## Overview

Shakapacker v10 replaces CommonJS `export =` syntax with standard ES module exports throughout the package. This improves TypeScript support and aligns with modern JavaScript standards.

## Why This Change?

### **Improved TypeScript Support**

Named exports provide better type inference and autocomplete in your webpack config files:

```typescript
// Before: Type inference can be lossy
const shakapacker = require('shakapacker')
shakapacker.config.  // Type hints may be limited

// After: Full type inference
import { config } from 'shakapacker'
config.  // Full autocomplete and type checking
```

### **Clearer, More Explicit Imports**

Import statements make it immediately obvious what your config depends on:

```javascript
// Before: Unclear what's being used
const shakapacker = require("shakapacker")
// ... somewhere later in the file
shakapacker.config.outputPath

// After: Clear at the top of the file
import { config, generateWebpackConfig } from "shakapacker"
config.outputPath
```

### **Modern JavaScript Standards**

ES modules are the standard syntax for modern JavaScript:

- Better IDE and editor support
- Consistent with how you import other packages
- Aligns with Node.js ESM direction

## Breaking Changes

### 1. Default Import No Longer Available

**Before (v9):**

```javascript
const shakapacker = require("shakapacker")
const config = shakapacker.config
const env = shakapacker.env
```

**After (v10):**

```javascript
import { config, railsEnv, nodeEnv, isProduction } from "shakapacker"
// or with CommonJS:
const { config, railsEnv, nodeEnv, isProduction } = require("shakapacker")
```

### 2. `env` Object Replaced with Named Exports

The `env` object has been replaced with individual named exports for better tree-shaking.

**Before (v9):**

```javascript
const { env } = require("shakapacker")
console.log(env.nodeEnv)
console.log(env.railsEnv)
console.log(env.isProduction)
```

**After (v10):**

```javascript
import {
  nodeEnv,
  railsEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer
} from "shakapacker"
console.log(nodeEnv)
console.log(railsEnv)
console.log(isProduction)
```

### 3. Webpack-Merge Utilities Are Re-Exported

**Before (v9):**

```javascript
const shakapacker = require("shakapacker")
const merged = shakapacker.merge(config1, config2)
```

**After (v10):**

```javascript
import { merge } from "shakapacker"
// or
import { merge } from "webpack-merge" // Direct import is also fine

const merged = merge(config1, config2)
```

## Migration Strategies

### Automated Migration

Use the provided migration script to automatically update your codebase:

```bash
# Migrate a single file
node node_modules/shakapacker/scripts/migrate-to-esm-exports.js config/webpack/webpack.config.js

# Migrate an entire directory
node node_modules/shakapacker/scripts/migrate-to-esm-exports.js config/webpack/

# Migrate your whole project (be careful!)
node node_modules/shakapacker/scripts/migrate-to-esm-exports.js .
```

**What the script does:**

- **Creates timestamped backups** (`.backup-TIMESTAMP`) before any modifications
- Converts `require('shakapacker')` to ES6 imports
- Updates `shakapacker.env.*` to use named env exports
- Converts `module.exports =` to `export default` (prevents mixing CJS/ESM syntax errors)
- Preserves other `require()` calls unrelated to Shakapacker
- **Aborts if backup creation fails** to prevent data loss

### Manual Migration

For more complex cases or if you prefer manual updates:

#### Example 1: Basic Webpack Config

**Before:**

```javascript
const { generateWebpackConfig } = require("shakapacker")

module.exports = generateWebpackConfig({
  // your config
})
```

**After:**

```javascript
import { generateWebpackConfig } from "shakapacker"

export default generateWebpackConfig({
  // your config
})
```

#### Example 2: Complex Config with env

**Before:**

```javascript
const { generateWebpackConfig, env, merge } = require("shakapacker")
const customConfig = require("./custom")

const config = generateWebpackConfig()

if (env.isProduction) {
  module.exports = merge(config, customConfig)
} else {
  module.exports = config
}
```

**After:**

```javascript
import { generateWebpackConfig, isProduction, merge } from "shakapacker"
import customConfig from "./custom.js"

const config = generateWebpackConfig()

export default isProduction ? merge(config, customConfig) : config
```

#### Example 3: Using Config in Scripts

**Before:**

```javascript
const { config } = require("shakapacker")

console.log("Output path:", config.outputPath)
console.log("Public path:", config.publicPath)
```

**After:**

```javascript
import { config } from "shakapacker"

console.log("Output path:", config.outputPath)
console.log("Public path:", config.publicPath)
```

#### Example 4: Custom Webpack Plugins

**Before:**

```javascript
const { generateWebpackConfig, config, env } = require("shakapacker")
const MyPlugin = require("./my-plugin")

module.exports = generateWebpackConfig({
  plugins: [
    new MyPlugin({
      isDev: env.isDevelopment,
      outputPath: config.outputPath
    })
  ]
})
```

**After:**

```javascript
import { generateWebpackConfig, config, isDevelopment } from "shakapacker"
import MyPlugin from "./my-plugin.js"

export default generateWebpackConfig({
  plugins: [
    new MyPlugin({
      isDev: isDevelopment,
      outputPath: config.outputPath
    })
  ]
})
```

## Complete Export Reference

### Main Exports (from 'shakapacker')

```typescript
import {
  // Configuration
  config, // Shakapacker configuration object
  devServer, // Dev server configuration
  generateWebpackConfig, // Main function to generate webpack config
  baseConfig, // Base webpack configuration

  // Environment
  railsEnv, // Rails environment (string)
  nodeEnv, // Node environment (string)
  isProduction, // Boolean: is production?
  isDevelopment, // Boolean: is development?
  runningWebpackDevServer, // Boolean: is dev server running?

  // Rules and Helpers
  rules, // Webpack rules array
  moduleExists, // Check if a module exists
  canProcess, // Check if a file can be processed
  inliningCss, // CSS inlining configuration

  // Webpack-merge utilities (re-exported)
  merge,
  mergeWithCustomize,
  mergeWithRules,
  unique
} from "shakapacker"
```

### Rspack Exports (from 'shakapacker/rspack')

```typescript
import {
  // Same as main exports, but with Rspack-specific config
  config,
  devServer,
  generateRspackConfig, // Note: Rspack-specific function name
  baseConfig,
  railsEnv,
  nodeEnv,
  isProduction,
  isDevelopment,
  runningWebpackDevServer,
  rules,
  moduleExists,
  canProcess,
  inliningCss,

  // Webpack-merge utilities
  merge,
  mergeWithCustomize,
  mergeWithRules,
  unique
} from "shakapacker/rspack"
```

## Common Migration Issues

### Issue 1: Module Not Found

**Error:** `Cannot find module 'shakapacker'`

**Solution:** Ensure you've updated your `package.json`:

```bash
npm install shakapacker@^10.0.0
# or
yarn add shakapacker@^10.0.0
```

### Issue 2: env is not defined

**Error:** `ReferenceError: env is not defined`

**Solution:** Import the specific env properties you need:

```javascript
// Before
const { env } = require("shakapacker")
console.log(env.nodeEnv)

// After
import { nodeEnv } from "shakapacker"
console.log(nodeEnv)
```

### Issue 3: Type Errors in TypeScript

**Error:** `Property 'env' does not exist on type...`

**Solution:** Update your imports to use the individual exports:

```typescript
// Before
import * as shakapacker from "shakapacker"
const isDev = shakapacker.env.isDevelopment

// After
import { isDevelopment } from "shakapacker"
const isDev = isDevelopment
```

## Testing Your Migration

After migrating, test your application thoroughly:

1. **Build your assets:**

   ```bash
   npm run build
   # or
   yarn build
   ```

2. **Start your development server:**

   ```bash
   npm run dev
   # or
   ./bin/dev
   ```

3. **Run your test suite:**

   ```bash
   npm test
   # or
   bundle exec rspec
   ```

4. **Check for console errors** in your browser's developer tools

## Gradual Migration Strategy

If you have a large codebase, consider migrating gradually:

1. **Start with new files:** Use ES modules for any new webpack config files
2. **Migrate one config at a time:** Update one webpack config file per PR
3. **Test thoroughly:** Ensure each migration works before moving on
4. **Update documentation:** Document any custom patterns your team uses

## Rollback Plan

If you need to rollback to v9:

1. **Revert your package.json:**

   ```bash
   npm install shakapacker@^9.0.0
   # or
   yarn add shakapacker@^9.0.0
   ```

2. **Revert your config files** (if you committed them separately)

3. **Clear your build cache:**
   ```bash
   rm -rf public/packs
   npm run build
   ```

## Getting Help

If you encounter issues during migration:

- **Check the docs:** [docs/v10-migration-guide.md](./v10-migration-guide.md)
- **Search issues:** [Shakapacker GitHub Issues](https://github.com/shakacode/shakapacker/issues)
- **Ask for help:** Create a new issue with the `migration` label

## Summary Checklist

- [ ] Update Shakapacker to v10: `npm install shakapacker@^10.0.0`
- [ ] Run migration script: `node node_modules/shakapacker/scripts/migrate-to-esm-exports.js config/`
- [ ] Replace `env` object with individual exports (`railsEnv`, `nodeEnv`, etc.)
- [ ] Update any custom webpack configs to use named imports
- [ ] Test your build: `npm run build`
- [ ] Test your dev server: `npm run dev`
- [ ] Run your test suite
- [ ] Check for console errors in browser
- [ ] Update team documentation
- [ ] Celebrate! 🎉
