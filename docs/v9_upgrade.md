# Shakapacker v9 Upgrade Guide

This guide outlines breaking changes and migration steps for upgrading from Shakapacker v8 to v9.

## Breaking Changes

### 1. CSS Modules Now Use Named Exports by Default

**What changed:** CSS Modules now use named exports with camelCase conversion by default, aligning with Next.js and modern tooling standards.

**Before (v8):**
```js
import styles from './Component.module.css';
<button className={styles.button} />
```

**After (v9):**
```js
import { button } from './Component.module.css';
<button className={button} />
```

**Migration Options:**

1. **Update your code** (Recommended):
   - Change imports from default to named exports
   - Update className references to use imported names directly
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

### 3. Rspack Support Added

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
  const classes: { [key: string]: string };
  export = classes;  // v9 named exports
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