# Rspack Migration Guide for Shakapacker

> 💡 **Quick Start**: For a step-by-step migration guide from Webpack to Rspack, see [Common Upgrades Guide - Webpack to Rspack](./common-upgrades.md#migrating-from-webpack-to-rspack).

## Overview

This guide documents the differences between webpack and Rspack configurations in Shakapacker, and provides migration guidance for users switching to Rspack.

## Key Differences from Webpack

### 1. Built-in Loaders

Rspack provides built-in loaders for better performance:

**JavaScript/TypeScript:**

- Use `builtin:swc-loader` instead of `babel-loader` or `ts-loader`
- 20x faster than Babel on single thread, 70x on multiple cores
- Configuration example:

```javascript
{
  test: /\.(js|jsx|ts|tsx)$/,
  loader: 'builtin:swc-loader',
  options: {
    jsc: {
      parser: {
        syntax: 'typescript', // or 'ecmascript'
        tsx: true, // for TSX files
        jsx: true  // for JSX files
      },
      transform: {
        react: {
          runtime: 'automatic'
        }
      }
    }
  }
}
```

### 2. Plugin Replacements

#### Built-in Rspack Alternatives

| Webpack Plugin                 | Rspack Alternative                         | Status      |
| ------------------------------ | ------------------------------------------ | ----------- |
| `copy-webpack-plugin`          | `rspack.CopyRspackPlugin`                  | ✅ Built-in |
| `mini-css-extract-plugin`      | `rspack.CssExtractRspackPlugin`            | ✅ Built-in |
| `terser-webpack-plugin`        | `rspack.SwcJsMinimizerRspackPlugin`        | ✅ Built-in |
| `css-minimizer-webpack-plugin` | `rspack.LightningCssMinimizerRspackPlugin` | ✅ Built-in |

#### Community Alternatives

| Webpack Plugin                         | Rspack Alternative             | Package                                 |
| -------------------------------------- | ------------------------------ | --------------------------------------- |
| `fork-ts-checker-webpack-plugin`       | `ts-checker-rspack-plugin`     | `npm i -D ts-checker-rspack-plugin`     |
| `@pmmmwh/react-refresh-webpack-plugin` | `@rspack/plugin-react-refresh` | `npm i -D @rspack/plugin-react-refresh` |
| `eslint-webpack-plugin`                | `eslint-rspack-plugin`         | `npm i -D eslint-rspack-plugin`         |

#### Incompatible Plugins

The following webpack plugins are NOT compatible with Rspack:

- `webpack.optimize.LimitChunkCountPlugin` - Use `optimization.splitChunks` configuration instead
- `webpack-manifest-plugin` - Use `rspack-manifest-plugin` instead
- Git revision plugins - Use alternative approaches

### 3. Asset Module Types

Replace file loaders with asset modules:

- `file-loader` → `type: 'asset/resource'`
- `url-loader` → `type: 'asset/inline'`
- `raw-loader` → `type: 'asset/source'`

### 4. Configuration Differences

#### TypeScript Configuration

**Required:** Add `isolatedModules: true` to your `tsconfig.json`:

```json
{
  "compilerOptions": {
    "isolatedModules": true
  }
}
```

#### React Fast Refresh

```javascript
// Development configuration
const ReactRefreshPlugin = require("@rspack/plugin-react-refresh")

module.exports = {
  plugins: [new ReactRefreshPlugin(), new rspack.HotModuleReplacementPlugin()]
}
```

### 5. Optimization Differences

#### Code Splitting

Rspack's `splitChunks` configuration is similar to webpack but with some differences:

```javascript
optimization: {
  splitChunks: {
    chunks: 'all',
    cacheGroups: {
      vendor: {
        test: /[\\/]node_modules[\\/]/,
        priority: -10,
        reuseExistingChunk: true
      }
    }
  }
}
```

#### Minimization

```javascript
optimization: {
  minimize: true,
  minimizer: [
    new rspack.SwcJsMinimizerRspackPlugin(),
    new rspack.LightningCssMinimizerRspackPlugin()
  ]
}
```

### 6. Development Server

Rspack uses its own dev server with some configuration differences:

```javascript
devServer: {
  // Rspack-specific: Force writing assets to disk
  devMiddleware: {
    writeToDisk: true
  }
}
```

## Migration Checklist

### Quick Start: Using the Switch Bundler Task

Shakapacker provides a convenient rake task to switch between webpack and rspack:

```bash
# Switch to rspack with automatic dependency management
rails shakapacker:switch_bundler rspack --install-deps
# or with rake (note the -- separator)
rake shakapacker:switch_bundler rspack -- --install-deps

# Fast switching without uninstalling old bundler (keeps both)
rails shakapacker:switch_bundler webpack --install-deps --no-uninstall
rake shakapacker:switch_bundler rspack -- --install-deps --no-uninstall

# Switch to rspack manually (you manage dependencies yourself)
rails shakapacker:switch_bundler rspack
rake shakapacker:switch_bundler rspack

# Switch back to webpack if needed
rails shakapacker:switch_bundler webpack --install-deps
rake shakapacker:switch_bundler webpack -- --install-deps

# Show help
rails shakapacker:switch_bundler --help
rake shakapacker:switch_bundler -- --help
```

**Note:** When using `rake`, you must use `--` to separate rake options from task arguments.

The task will:

- Update `config/shakapacker.yml` to switch the bundler
- Optionally install/uninstall npm dependencies with `--install-deps`
- Use `--no-uninstall` to skip uninstalling the old bundler's packages (faster switching, keeps both bundlers installed)
- Update `javascript_transpiler` to `swc` when switching to rspack (recommended)
- Preserve your config file comments and structure

**Custom Dependencies:** You can customize which dependencies are installed by creating a `.shakapacker-switch-bundler-dependencies.yml` file:

```bash
rails shakapacker:switch_bundler --init-config
```

### Manual Migration Steps

If you prefer to migrate manually or need more control:

### Step 1: Update Dependencies

```bash
# Remove webpack dependencies
npm uninstall webpack webpack-cli webpack-dev-server

# Install Rspack
npm install --save-dev @rspack/core @rspack/cli
```

### Step 2: Update Configuration Files

1. Create `config/rspack/rspack.config.js` based on your webpack config
2. Update `config/shakapacker.yml`:

```yaml
assets_bundler: "rspack"
```

### Step 3: Replace Loaders

- Replace `babel-loader` with `builtin:swc-loader`
- Remove `file-loader`, `url-loader`, `raw-loader` - use asset modules
- Update CSS loaders to use Rspack's built-in support

### Step 4: Update Plugins

- Replace plugins with Rspack alternatives (see table above)
- Remove incompatible plugins
- Add Rspack-specific plugins as needed

### Step 5: TypeScript Setup

1. Add `isolatedModules: true` to `tsconfig.json`
2. Optional: Add `ts-checker-rspack-plugin` for type checking

### Step 6: Test Your Build

```bash
# Development build
bin/shakapacker

# Production build
bin/shakapacker --mode production
```

## Common Issues and Solutions

### Issue: LimitChunkCountPlugin Error

**Error:** `Cannot read properties of undefined (reading 'tap')`
**Solution:** Remove `webpack.optimize.LimitChunkCountPlugin` and use `splitChunks` configuration instead.

### Issue: Missing Loaders

**Error:** Module parse errors
**Solution:** Check console logs for skipped loaders and install missing dependencies.

### Issue: CSS Extraction

**Error:** CSS not being extracted properly
**Solution:** Use `rspack.CssExtractRspackPlugin` instead of `mini-css-extract-plugin`.

### Issue: TypeScript Errors

**Error:** TypeScript compilation errors
**Solution:** Ensure `isolatedModules: true` is set in `tsconfig.json`.

## Performance Tips

1. **Use Built-in Loaders:** Always prefer Rspack's built-in loaders for better performance
2. **Minimize Plugins:** Use only necessary plugins as each adds overhead
3. **Enable Caching:** Rspack has built-in persistent caching
4. **Use SWC:** The built-in SWC loader is significantly faster than Babel

## Debugging Configuration

To compare your webpack and rspack configurations during migration:

```bash
# Export webpack configs before switching
bin/export-bundler-config --doctor

# Switch to rspack
rails shakapacker:switch_bundler rspack --install-deps

# Export rspack configs to compare
bin/export-bundler-config --doctor

# Compare the files in shakapacker-config-exports/
diff shakapacker-config-exports/webpack-production-client.yaml \
     shakapacker-config-exports/rspack-production-client.yaml
```

The config export utility creates annotated YAML files that make it easy to:

- Verify plugin replacements are correct
- Compare loader configurations
- Identify missing or different options
- Debug configuration issues

See the [Troubleshooting Guide](./troubleshooting.md#exporting-webpack--rspack-configuration) for more details.

## Resources

- [Rspack Documentation](https://rspack.rs)
- [Rspack Examples](https://github.com/rspack-contrib/rspack-examples)
- [Awesome Rspack](https://github.com/rspack-contrib/awesome-rspack)
- [Migration Guide](https://rspack.rs/guide/migration/webpack)
