# CSS Modules Export Mode

Most React guides and tutorials expect to import CSS Modules using a **default export object**:

```js
import styles from './Foo.module.css';
<button className={styles.bright} />
```

However, depending on configuration, `css-loader` may instead emit **named exports**:

```js
import { bright } from './Foo.module.css';
<button className={bright} />
```

By default, Shakapacker currently leaves `css-loader`'s `modules.namedExport` option unset, which leads to **named exports** being used in many cases. This can surprise developers expecting the `import styles ...` pattern.

---

## How to Configure Shakapacker for Default Exports

To force the more familiar `import styles ...` behavior (i.e. `namedExport: false`), update your webpack configuration as follows.

### Option 1: Update `config/webpack/commonWebpackConfig.js` (Recommended)

This approach modifies the common webpack configuration that applies to all environments:

```js
// config/webpack/commonWebpackConfig.js
const { generateWebpackConfig, merge } = require('shakapacker');

const baseClientWebpackConfig = generateWebpackConfig();

// Override CSS Modules configuration to use default exports instead of named exports
const overrideCssModulesConfig = (config) => {
  // Find the CSS rule in the module rules
  const cssRule = config.module.rules.find(rule =>
    rule.test && rule.test.toString().includes('css')
  );

  if (cssRule && cssRule.use) {
    const cssLoaderUse = cssRule.use.find(use =>
      use.loader && use.loader.includes('css-loader')
    );

    if (cssLoaderUse && cssLoaderUse.options && cssLoaderUse.options.modules) {
      // Set namedExport to false for default export behavior
      cssLoaderUse.options.modules.namedExport = false;
      cssLoaderUse.options.modules.exportLocalsConvention = 'asIs';
    }
  }

  return config;
};

const commonOptions = {
  resolve: {
    extensions: ['.css', '.ts', '.tsx'],
  },
};

const commonWebpackConfig = () => {
  const config = merge({}, baseClientWebpackConfig, commonOptions);
  return overrideCssModulesConfig(config);
};

module.exports = commonWebpackConfig;
```

### Option 2: Create `config/webpack/environment.js` (Alternative)

If you prefer using a separate environment file:

```js
// config/webpack/environment.js
const { environment } = require('@shakacode/shakapacker');
const getStyleRule = require('@shakacode/shakapacker/package/utils/getStyleRule');

// CSS Modules rule for *.module.css with default export enabled
const cssModulesRule = getStyleRule(/\.module\.css$/i, [], {
  sourceMap: true,
  importLoaders: 2,
  modules: {
    auto: true,
    namedExport: false,            // <-- key: enable default export object
    exportLocalsConvention: 'asIs' // keep your class names as-is
  }
});

// Ensure this rule wins for *.module.css
if (cssModulesRule) {
  environment.loaders.prepend('css-modules', cssModulesRule);
}

// Plain CSS rule for non-modules
const plainCssRule = getStyleRule(/(?<!\.module)\.css$/i, [], {
  sourceMap: true,
  importLoaders: 2,
  modules: false
});

if (plainCssRule) {
  environment.loaders.append('css', plainCssRule);
}

module.exports = environment;
```

Then reference this in your environment-specific configs (development.js, production.js, etc.).

### Option 3: (Optional) Sass Modules

If you also use Sass modules, add similar configuration for SCSS files:

```js
// For Option 1 approach, extend the overrideCssModulesConfig function:
const overrideCssModulesConfig = (config) => {
  // Handle both CSS and SCSS rules
  const styleRules = config.module.rules.filter(rule =>
    rule.test && (rule.test.toString().includes('css') || rule.test.toString().includes('scss'))
  );

  styleRules.forEach(rule => {
    if (rule.use) {
      const cssLoaderUse = rule.use.find(use =>
        use.loader && use.loader.includes('css-loader')
      );

      if (cssLoaderUse && cssLoaderUse.options && cssLoaderUse.options.modules) {
        cssLoaderUse.options.modules.namedExport = false;
        cssLoaderUse.options.modules.exportLocalsConvention = 'asIs';
      }
    }
  });

  return config;
};
```

---

## Verifying the Configuration

### 1. Rebuild Your Packs

After making the configuration changes, rebuild your webpack bundles:

```bash
# For development
NODE_ENV=development bin/shakapacker

# Or with the dev server
bin/shakapacker-dev-server
```

### 2. Test in Your React Component

Update your component to use default imports:

```js
// Before (named exports)
import { bright } from './Foo.module.css';

// After (default export)
import styles from './Foo.module.css';
console.log(styles); // { bright: 'Foo_bright__hash' }
```

### 3. Debug Webpack Configuration (Optional)

To inspect the final webpack configuration:

```bash
NODE_ENV=development bin/shakapacker --profile --json > /tmp/webpack-stats.json
```

Then search for `css-loader` options in the generated JSON file.

---

## Benefits of Default Export Approach

1. **Better Developer Experience**: Matches most React tutorials and documentation
2. **IDE Support**: Better autocomplete and IntelliSense for CSS class names
3. **Type Safety**: Easier to add TypeScript definitions for CSS modules
4. **Consistency**: Aligns with common React ecosystem practices

---

## Migration Guide

If you're migrating from named exports to default exports:

### 1. Update Import Statements

```js
// Old (named exports)
import { bright, container, button } from './Component.module.css';

// New (default export)
import styles from './Component.module.css';
```

### 2. Update Class References

```js
// Old
<div className={container}>
  <button className={button}>Click me</button>
  <span className={bright}>Highlighted text</span>
</div>

// New
<div className={styles.container}>
  <button className={styles.button}>Click me</button>
  <span className={styles.bright}>Highlighted text</span>
</div>
```

### 3. Consider Using a Codemod

For large codebases, consider writing a codemod to automate the migration:

```bash
# Example using jscodeshift (pseudocode)
npx jscodeshift -t css-modules-migration.js src/
```

---

## Future Shakapacker Configuration

In future versions of Shakapacker, this configuration may be exposed via `config/shakapacker.yml`:

```yml
# Future configuration (not yet implemented)
css_modules:
  # true  -> named exports (import { bright } ...)
  # false -> default export (import styles ...)
  named_export: false
```

- **Current behavior:** Uses named exports when unset
- **Future behavior:** New app templates will default to `false`
- **Next major release:** The default will change to `false` when unset

---

## Troubleshooting

### CSS Classes Not Applying

If your CSS classes aren't applying after the change:

1. **Check import syntax**: Ensure you're using `import styles from ...`
2. **Verify class names**: Use `console.log(styles)` to see available classes
3. **Rebuild webpack**: Clear cache and rebuild: `rm -rf tmp/cache && bin/shakapacker`

### TypeScript Support

For TypeScript projects, create type definitions for your CSS modules:

```typescript
// src/types/css-modules.d.ts
declare module '*.module.css' {
  const classes: { [key: string]: string };
  export default classes;
}
```

### Build Performance

The configuration changes should not impact build performance significantly. If you experience issues:

1. Check webpack stats: `bin/shakapacker --profile`
2. Verify only necessary rules are being modified
3. Consider using webpack bundle analyzer for deeper insights

---

## Summary

- **Current default**: Named exports (`import { bright } ...`)
- **Recommended for DX**: Default export (`import styles ...`)
- **Implementation**: Override CSS loader configuration in `commonWebpackConfig.js`
- **Migration**: Update imports and class references systematically
- **Future**: Shakapacker will provide native configuration options
