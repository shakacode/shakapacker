# Shakapacker v9 Upgrade Guide

This guide outlines new features, breaking changes, and migration steps for upgrading from Shakapacker v8 to v9.

> **⚠️ Important for v9.1.0 Users:** If you're upgrading to v9.1.0 or later, please note the [SWC Configuration Breaking Change](#swc-loose-mode-breaking-change-v910) below. This affects users who previously configured SWC in v9.0.0.

## New Features

### TypeScript Support

Shakapacker v9 includes TypeScript definitions for better IDE support and type safety.

- **No breaking changes** - JavaScript configs continue to work
- **Optional** - Use TypeScript only if you want it
- **Type safety** - Catch configuration errors at compile-time
- **IDE support** - Full autocomplete for all options

See the [TypeScript Documentation](./typescript.md) for usage examples.

### NODE_ENV Default Behavior Fixed

**What changed:** NODE_ENV now intelligently defaults based on RAILS_ENV instead of always defaulting to "production".

**New behavior:**

- When `RAILS_ENV=production` → `NODE_ENV` defaults to `"production"`
- When `RAILS_ENV=development` or unset → `NODE_ENV` defaults to `"development"`
- When `RAILS_ENV` is any other value (test, staging, etc.) → `NODE_ENV` defaults to `"development"`

**Benefits:**

- **Dev server "just works"** - No need to explicitly set NODE_ENV when running the development server
- **Correct configuration loaded** - Development server now properly loads the development configuration from shakapacker.yml
- **Fixes port issues** - Dev server uses the configured port (e.g., 3035) instead of defaulting to 8080
- **Fixes 404 errors** - Assets load correctly without requiring manual NODE_ENV configuration

**No action required** - This change improves the default behavior and requires no migration.

**If you previously worked around this bug**, you can now remove these workarounds:

- Remove `NODE_ENV=development` from your `.env`, `.env.development`, or `.env.local` files
- Remove `NODE_ENV=development` from your `docker-compose.yml` or Dockerfile
- Remove custom scripts that set NODE_ENV before running the dev server
- Remove `NODE_ENV=development` from your `bin/dev` or Procfile.dev

## SWC Loose Mode Breaking Change (v9.1.0)

> **⚠️ This breaking change was introduced in v9.1.0.** If you're upgrading from v9.0.0, pay special attention to this section.

**What changed:** SWC default configuration now uses `loose: false` instead of `loose: true`.

**Why:** The previous default of `loose: true` caused:

- **Silent failures with Stimulus controllers** - Controllers wouldn't register properly
- **Incorrect behavior with spread operators** on iterables (e.g., `[...new Set()]`)
- **Deviation from SWC and Babel defaults** - Both tools default to `loose: false`

**Impact:**

- **Most projects:** No action needed. The new default is more correct and fixes bugs.
- **Stimulus users:** This fixes silent controller failures you may have experienced.
- **Projects relying on loose mode behavior:** May need to explicitly configure `loose: true` (not recommended).

**When you might need the old behavior:**

- If you have code that breaks with spec-compliant transforms
- Note: `loose: true` provides slightly faster build times but generates less spec-compliant code

**How to restore old behavior (not recommended):**

Create or update `config/swc.config.js`:

```javascript
module.exports = {
  options: {
    jsc: {
      // Only use this if you have code that requires loose transforms.
      // This provides slightly faster build performance but may cause runtime bugs.
      loose: true // Restore v9.0.0 behavior
    }
  }
}
```

**Better solution:** Fix your code to work with spec-compliant transforms. The `loose: false` default aligns with both SWC and Babel standards and prevents subtle bugs.

**Using Stimulus?** The new default includes `keepClassNames: true` to prevent SWC from mangling class names. If you use `rake shakapacker:migrate_to_swc`, this is configured automatically. See [Using SWC with Stimulus](./using_swc_loader.md#using-swc-with-stimulus) for details.

## Breaking Changes

### 1. CSS Modules Configuration Changed to Named Exports

**What changed:** CSS Modules are now configured with `namedExport: true` and `exportLocalsConvention: 'camelCaseOnly'` by default, aligning with Next.js and modern tooling standards.

> **Important:** When `namedExport: true` is enabled, css-loader requires `exportLocalsConvention` to be either `'camelCaseOnly'` or `'dashesOnly'`. Using `'camelCase'` will cause a build error: `"exportLocalsConvention" with "camelCase" value is incompatible with "namedExport: true" option`.

**Quick Reference: Configuration Options**

| Configuration   | namedExport | exportLocalsConvention | CSS: `.my-button` | Export Available                  | Works With        |
| --------------- | ----------- | ---------------------- | ----------------- | --------------------------------- | ----------------- |
| **v9 Default**  | `true`      | `'camelCaseOnly'`      | `.my-button`      | `myButton` only                   | ✅ Named exports  |
| **Alternative** | `true`      | `'dashesOnly'`         | `.my-button`      | `'my-button'` only                | ✅ Named exports  |
| **v8 Style**    | `false`     | `'camelCase'`          | `.my-button`      | Both `myButton` AND `'my-button'` | ✅ Default export |
| **❌ Invalid**  | `true`      | `'camelCase'`          | -                 | -                                 | ❌ Build Error    |

**JavaScript Projects:**

```js
// Before (v8)
import styles from "./Component.module.css"
;<button className={styles.button} />

// After (v9)
import { button } from "./Component.module.css"
;<button className={button} />
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
webpack_loader: "babel"
```

**After (v9):**

```yml
# config/shakapacker.yml
javascript_transpiler: "babel"
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
javascript_transpiler: "swc"
```

Then install SWC:

```bash
npm install @swc/core swc-loader
```

#### Option 2: Keep using Babel

```yml
# config/shakapacker.yml
javascript_transpiler: "babel"
```

No other changes needed - your existing babel packages will continue to work.

#### Option 3: Use esbuild

```yml
# config/shakapacker.yml
javascript_transpiler: "esbuild"
```

Then install esbuild:

```bash
npm install esbuild esbuild-loader
```

### 4. Rspack Support Added

**New feature:** Shakapacker v9 adds support for Rspack as an alternative bundler to webpack.

```yml
# config/shakapacker.yml
assets_bundler: "rspack" # or 'webpack' (default)
```

### 5. All Peer Dependencies Now Optional

**What changed:** All peer dependencies are now marked as optional via `peerDependenciesMeta`.

**Benefits:**

- **No installation warnings** - You won't see peer dependency warnings for packages you don't use
- **Install only what you need** - Using webpack? Don't install rspack. Using SWC? Don't install Babel.
- **Clear version constraints** - When you do install a package, version compatibility is still enforced

**What this means for you:**

- **Existing projects:** No changes needed. Your existing dependencies will continue to work.
- **New projects:** The installer only adds the packages you actually need based on your configuration.
- **Package manager behavior:** npm, yarn, and pnpm will no longer warn about missing peer dependencies.

**Example:** If you're using SWC with webpack, you only need:

```json
{
  "dependencies": {
    "shakapacker": "^9.0.0",
    "@swc/core": "^1.3.0",
    "swc-loader": "^0.2.0",
    "webpack": "^5.76.0",
    "webpack-cli": "^5.0.0",
    "webpack-dev-server": "^5.0.0"
  }
}
```

You won't get warnings about missing Babel, Rspack, or esbuild packages.

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
import styles from "./styles.module.css"

// Replace with named imports:
import { className1, className2 } from "./styles.module.css"
```

#### Update TypeScript definitions:

```typescript
// Update your CSS module type definitions
declare module "*.module.css" {
  // With namedExport: true, css-loader generates individual named exports
  // TypeScript can't know the exact names at compile time, so we declare
  // a module with any number of string exports
  const classes: { readonly [key: string]: string }
  export = classes
  // Note: This allows 'import * as styles' but not 'import styles from'
  // because css-loader with namedExport: true doesn't generate a default export
}
```

### Step 3: Handle Kebab-Case Class Names

v9 automatically converts kebab-case to camelCase with `exportLocalsConvention: 'camelCaseOnly'`:

```css
/* styles.module.css */
.my-button {
}
.primary-color {
}
```

```js
// v9 default - camelCase conversion
import { myButton, primaryColor } from "./styles.module.css"
```

**Alternative: Keep kebab-case names with 'dashesOnly'**

If you prefer to keep kebab-case names in JavaScript, you can override the configuration to use `'dashesOnly'`:

```js
// config/webpack/commonWebpackConfig.js
modules: {
  namedExport: true,
  exportLocalsConvention: 'dashesOnly'  // Keep original kebab-case names
}
```

Then use the original kebab-case names in your imports:

```js
// With dashesOnly configuration
import { 'my-button': myButton, 'primary-color': primaryColor } from './styles.module.css';
// or access as properties
import * as styles from './styles.module.css';
const buttonClass = styles['my-button'];
```

**Note:** With `'camelCaseOnly'` (default) or `'dashesOnly'`, only one version is exported. If you need both the original and camelCase versions, you would need to use `'camelCase'` instead, but this requires `namedExport: false` (v8 behavior). See the [CSS Modules Export Mode documentation](./css-modules-export-mode.md) for details on reverting to v8 behavior.

### Step 4: Update Configuration Files

If you have `webpack_loader` in your configuration:

```yml
# config/shakapacker.yml
# OLD:
# webpack_loader: 'babel'

# NEW:
javascript_transpiler: "babel"
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

### Build Error: exportLocalsConvention Incompatible with namedExport

If you see this error:

```
"exportLocalsConvention" with "camelCase" value is incompatible with "namedExport: true" option
```

This means your webpack configuration has `namedExport: true` with `exportLocalsConvention: 'camelCase'`. The fix is to change to `'camelCaseOnly'` or `'dashesOnly'`:

```js
// config/webpack/commonWebpackConfig.js or wherever you configure css-loader
modules: {
  namedExport: true,
  exportLocalsConvention: 'camelCaseOnly'  // or 'dashesOnly'
}
```

If you want to use `'camelCase'` (which exports both original and camelCase versions), you must set `namedExport: false` and revert to v8 behavior. See the [CSS Modules Export Mode documentation](./css-modules-export-mode.md) for details.

### Unexpected Peer Dependency Warnings After Upgrade

If you experience unexpected peer dependency warnings after upgrading to v9, you may need to clear your package manager's cache and reinstall dependencies. This ensures the new optional peer dependency configuration takes effect properly.

**For npm:**

```bash
rm -rf node_modules package-lock.json
npm install
```

**For Yarn:**

```bash
rm -rf node_modules yarn.lock
yarn install
```

**For pnpm:**

```bash
rm -rf node_modules pnpm-lock.yaml
pnpm install
```

**For Bun:**

```bash
rm -rf node_modules bun.lockb
bun install
```

**When is this necessary?**

- If you see peer dependency warnings for packages you don't use (e.g., warnings about Babel when using SWC)
- If your package manager cached the old dependency resolution from v8
- After switching transpilers or bundlers (e.g., from Babel to SWC, or webpack to rspack)

**Note:** This is typically only needed once after the v8 → v9 upgrade. Subsequent installs will use the correct dependency resolution.

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
