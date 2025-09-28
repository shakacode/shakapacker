# Shakapacker v9 Upgrade Guide

This guide outlines breaking changes and migration steps for upgrading from Shakapacker v8 to v9.

## Breaking Changes

### 1. CSS Modules Configuration Changed to Named Exports

**What changed:** CSS Modules are now configured with `namedExport: true` and `exportLocalsConvention: 'camelCase'` by default, aligning with Next.js and modern tooling standards.

**JavaScript Projects:**
```js
// Before (v8)
import styles from './Component.module.css';
<button className={styles.button} />

// After (v9)
import { button } from './Component.module.css';
<button className={button} />
```

**TypeScript Projects:**
```typescript
// Before (v8)
import styles from './Component.module.css';
<button className={styles.button} />

// After (v9) - namespace import due to TypeScript limitations
import * as styles from './Component.module.css';
<button className={styles.button} />
```

**Migration Options:**

1. **Update your code** (Recommended):
   - JavaScript: Change to named imports (`import { className }`)
   - TypeScript: Change to namespace imports (`import * as styles`)
   - Kebab-case class names are automatically converted to camelCase

2. **Keep v8 behavior** temporarily:
   - Override the css-loader configuration as shown in [CSS Modules Export Mode documentation](./css-modules-export-mode.md)
   - This gives you time to migrate gradually

**Benefits of the change:**
- Eliminates webpack/TypeScript warnings
- Better tree-shaking of unused CSS classes
- More explicit about which classes are used
- Aligns with modern JavaScript standards

### 2. Configuration Option Renamed: `webpack_loader` → `javascript_transpiler`

**What changed:** The configuration option has been renamed to better reflect its purpose.

**Before (v8):**
```yml
# config/shakapacker.yml
webpack_loader: 'babel'
```

**After (v9):**
```yml
# config/shakapacker.yml
javascript_transpiler: 'babel'
```

**Note:** The old `webpack_loader` option is deprecated but still supported with a warning.

### 3. SWC is Now the Default JavaScript Transpiler

**What changed:** SWC replaces Babel as the default JavaScript transpiler. Babel is no longer included in peer dependencies.

**Why:** SWC is 20x faster than Babel while maintaining compatibility with most JavaScript and TypeScript code.

**Impact on existing projects:**
- Your project will continue using Babel if you already have babel packages in package.json
- To switch to SWC for better performance, see migration options below

**Impact on new projects:**
- New installations will use SWC by default
- Babel dependencies won't be installed unless explicitly configured

### Migration Options

#### Option 1 (Recommended): Switch to SWC
```yml
# config/shakapacker.yml
javascript_transpiler: 'swc'
```
Then install SWC:
```bash
npm install @swc/core swc-loader
```

#### Option 2: Keep using Babel
```yml
# config/shakapacker.yml
javascript_transpiler: 'babel'
```
No other changes needed - your existing babel packages will continue to work.

#### Option 3: Use esbuild
```yml
# config/shakapacker.yml
javascript_transpiler: 'esbuild'
```
Then install esbuild:
```bash
npm install esbuild esbuild-loader
```

### 4. Rspack Support Added

**New feature:** Shakapacker v9 adds support for Rspack as an alternative bundler to webpack.

```yml
# config/shakapacker.yml
assets_bundler: 'rspack'  # or 'webpack' (default)
```

## Migration Steps

### Step 1: Update Dependencies

```bash
npm update shakapacker@^9.0.0
# or
yarn upgrade shakapacker@^9.0.0
```

### Step 2: Update CSS Module Imports

#### For each CSS module import:

```js
// Find imports like this:
import styles from './styles.module.css';

// Replace with named imports:
import { className1, className2 } from './styles.module.css';
```

#### Update TypeScript definitions:

```typescript
// Update your CSS module type definitions
declare module '*.module.css' {
  // With namedExport: true, css-loader generates individual named exports
  // TypeScript can't know the exact names at compile time, so we declare
  // a module with any number of string exports
  const classes: { readonly [key: string]: string };
  export = classes;
  // Note: This allows 'import * as styles' but not 'import styles from'
  // because css-loader with namedExport: true doesn't generate a default export
}
```

### Step 3: Handle Kebab-Case Class Names

v9 automatically converts kebab-case to camelCase:

```css
/* styles.module.css */
.my-button { }
.primary-color { }
```

```js
// v9 imports
import { myButton, primaryColor } from './styles.module.css';
```

### Step 4: Update Configuration Files

If you have `webpack_loader` in your configuration:

```yml
# config/shakapacker.yml
# OLD:
# webpack_loader: 'babel'

# NEW:
javascript_transpiler: 'babel'
```

### Step 5: Run Tests

```bash
# Run your test suite
npm test

# Build your application
bin/shakapacker

# Test in development
bin/shakapacker-dev-server
```

## Troubleshooting

### CSS Classes Not Applying

- Ensure you're using named imports: `import { className } from '...'`
- Check camelCase conversion for kebab-case names
- Clear cache: `rm -rf tmp/cache && bin/shakapacker`

### TypeScript Errors

Update your global type definitions as shown in Step 2.

### Build Warnings

If you see warnings about CSS module exports, ensure you've updated all imports to use named exports or have properly configured the override.

## Need Help?

- See [CSS Modules Export Mode documentation](./css-modules-export-mode.md) for detailed configuration options
- Check the [CHANGELOG](../CHANGELOG.md) for all changes
- File issues at [GitHub Issues](https://github.com/shakacode/shakapacker/issues)

## Gradual Migration Strategy

If you have a large codebase and need to migrate gradually:

1. Override the CSS configuration to keep v8 behavior (see [documentation](./css-modules-export-mode.md))
2. Migrate files incrementally
3. Remove the override once migration is complete

This allows you to upgrade to v9 immediately while taking time to update your CSS module imports.