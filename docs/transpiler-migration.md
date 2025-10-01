# JavaScript Transpiler Configuration

## Default Transpilers

Shakapacker uses different default JavaScript transpilers based on the bundler:

- **Webpack**: `babel` (default) - Maintains backward compatibility
- **Rspack**: `swc` (default) - Modern, faster transpiler for new bundler

## Available Transpilers

- `babel` - Traditional JavaScript transpiler with wide ecosystem support
- `swc` - Rust-based transpiler, 20-70x faster than Babel
- `esbuild` - Go-based transpiler, extremely fast
- `none` - No transpilation (use native JavaScript)

## Configuration

Set the transpiler in your `config/shakapacker.yml`:

```yaml
default: &default
  # For webpack users (babel is default, no change needed)
  javascript_transpiler: babel
  
  # To opt-in to SWC for better performance
  javascript_transpiler: swc
  
  # For rspack users (swc is default, no change needed)
  assets_bundler: rspack
  javascript_transpiler: swc
```

## Migration Guide

### Migrating from Babel to SWC

SWC offers significant performance improvements while maintaining high compatibility with Babel.

#### 1. Install SWC dependencies

```bash
yarn add --dev @swc/core swc-loader
```

#### 2. Update your configuration

```yaml
# config/shakapacker.yml
default: &default
  javascript_transpiler: swc
```

#### 3. Create SWC configuration (optional)

If you need custom transpilation settings, create `.swcrc`:

```json
{
  "$schema": "https://json.schemastore.org/swcrc",
  "jsc": {
    "parser": {
      "syntax": "ecmascript",
      "jsx": true,
      "dynamicImport": true
    },
    "transform": {
      "react": {
        "runtime": "automatic"
      }
    },
    "target": "es2015"
  },
  "module": {
    "type": "es6"
  }
}
```

#### 4. Update React configuration (if using React)

For React projects, ensure you have the correct refresh plugin:

```bash
# For webpack
yarn add --dev @pmmmwh/react-refresh-webpack-plugin

# For rspack
yarn add --dev @rspack/plugin-react-refresh
```

### Performance Comparison

Typical build time improvements when migrating from Babel to SWC:

| Project Size | Babel | SWC | Improvement |
|-------------|-------|-----|-------------|
| Small (<100 files) | 5s | 1s | 5x faster |
| Medium (100-500 files) | 20s | 3s | 6.7x faster |
| Large (500+ files) | 60s | 8s | 7.5x faster |

### Compatibility Notes

#### Babel Features Not Yet in SWC

- Some experimental/stage-0 proposals
- Custom Babel plugins (need SWC equivalents)
- Babel macros

#### Migration Checklist

- [ ] Back up your current configuration
- [ ] Install SWC dependencies
- [ ] Update `shakapacker.yml`
- [ ] Test your build locally
- [ ] Run your test suite
- [ ] Check browser compatibility
- [ ] Deploy to staging environment
- [ ] Monitor for any runtime issues

### Rollback Plan

If you encounter issues, rolling back is simple:

```yaml
# config/shakapacker.yml
default: &default
  javascript_transpiler: babel  # Revert to babel
```

Then rebuild your application:

```bash
bin/shakapacker clobber
bin/shakapacker compile
```

## Environment Variables

You can also control the transpiler via environment variables:

```bash
# Override config file setting
SHAKAPACKER_JAVASCRIPT_TRANSPILER=swc bin/shakapacker compile

# For debugging
SHAKAPACKER_DEBUG_CACHE=true bin/shakapacker compile
```

## Troubleshooting

### Issue: Build fails after switching to SWC

**Solution**: Ensure all SWC dependencies are installed:

```bash
yarn add --dev @swc/core swc-loader
```

### Issue: React Fast Refresh not working

**Solution**: Install the correct refresh plugin for your bundler:

```bash
# Webpack
yarn add --dev @pmmmwh/react-refresh-webpack-plugin

# Rspack  
yarn add --dev @rspack/plugin-react-refresh
```

### Issue: Decorators not working

**Solution**: Enable decorator support in `.swcrc`:

```json
{
  "jsc": {
    "parser": {
      "decorators": true,
      "decoratorsBeforeExport": true
    }
  }
}
```

## Further Reading

- [SWC Documentation](https://swc.rs/docs/getting-started)
- [Babel to SWC Migration Guide](https://swc.rs/docs/migrating-from-babel)
- [Rspack Configuration](https://www.rspack.dev/config/index)