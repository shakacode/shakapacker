# Rspack Integration

Shakapacker supports [Rspack](https://rspack.rs) as an alternative bundler to Webpack. Rspack is a fast Rust-based web bundler with webpack-compatible API that can significantly speed up your build times.

## Installation

First, install the required Rspack dependencies:

```bash
npm install @rspack/core @rspack/cli -D
# or
yarn add @rspack/core @rspack/cli -D
# or  
pnpm add @rspack/core @rspack/cli -D
# or
bun add @rspack/core @rspack/cli -D
```

Note: These packages are already listed as optional peer dependencies in Shakapacker, so you may see warnings if they're not installed.

## Configuration

To enable Rspack, update your `config/shakapacker.yml`:

```yaml
default: &default
  # ... other config options
  bundler: 'rspack'  # Change from 'webpack' to 'rspack'
```

## Configuration

Rspack uses its own configuration directory to keep things organized. Create your Rspack configuration file at `config/rspack/rspack.config.js`:

```javascript
const { generateRspackConfig } = require('shakapacker/rspack')

module.exports = generateRspackConfig()
```

### Custom Configuration

If you need to customize your Rspack configuration:

```javascript
const { generateRspackConfig } = require('shakapacker/rspack')

const rspackConfig = generateRspackConfig({
  plugins: [
    new SomeRspackCompatiblePlugin()
  ],
  resolve: {
    extensions: ['.ts', '.tsx', '.js', '.jsx']
  }
})

module.exports = rspackConfig
```

### Migration from Webpack Config

If you have an existing `config/webpack/webpack.config.js`, you can migrate it to `config/rspack/rspack.config.js`:

**Old (webpack.config.js):**
```javascript
const { generateWebpackConfig } = require('shakapacker')
module.exports = generateWebpackConfig()
```

**New (rspack.config.js):**
```javascript
const { generateRspackConfig } = require('shakapacker/rspack')
module.exports = generateRspackConfig()
```

> **Note:** Shakapacker will show a deprecation warning if you use `config/webpack/webpack.config.js` with `bundler: 'rspack'`. Please migrate to `config/rspack/rspack.config.js`.

## Key Differences from Webpack

### Built-in Loaders

Rspack has built-in loaders that are faster than their webpack counterparts:

- **JavaScript/TypeScript**: Uses `builtin:swc-loader` instead of `babel-loader`
- **CSS Extraction**: Uses `rspack.CssExtractRspackPlugin` instead of `mini-css-extract-plugin`
- **Asset Handling**: Uses built-in asset modules instead of `file-loader`/`url-loader`

### Plugin Compatibility

Most webpack plugins work with Rspack, but some have Rspack-specific alternatives:

| Webpack Plugin | Rspack Alternative | Status |
|---|---|---|
| `mini-css-extract-plugin` | `rspack.CssExtractRspackPlugin` | Built-in |
| `copy-webpack-plugin` | `rspack.CopyRspackPlugin` | Built-in |
| `terser-webpack-plugin` | `rspack.SwcJsMinimizerRspackPlugin` | Built-in |

### Minification

Rspack uses SWC for minification by default, which is significantly faster than Terser:

```javascript
optimization: {
  minimize: true,
  minimizer: [
    new rspack.SwcJsMinimizerRspackPlugin(),
    new rspack.SwcCssMinimizerRspackPlugin()
  ]
}
```

## Limitations

- **CoffeeScript**: Not supported with Rspack
- **Some Webpack Plugins**: May not be compatible; check Rspack documentation

## Commands

All existing Shakapacker commands work the same way and automatically use Rspack when configured:

```bash
# Build (automatically uses rspack when bundler: 'rspack')
./bin/shakapacker

# Development server (automatically uses rspack when bundler: 'rspack')  
./bin/shakapacker-dev-server

# Watch mode
./bin/shakapacker --watch
```

The same dev server configuration in `shakapacker.yml` applies to both webpack and rspack.

## Performance Benefits

Rspack typically provides:

- **2-10x faster** cold builds
- **5-20x faster** incremental builds  
- **Faster HMR** (Hot Module Replacement)
- **Lower memory usage**

## Migration Checklist

1. **Install Rspack dependencies:**
   ```bash
   npm install @rspack/core @rspack/cli -D
   ```

2. **Update configuration:**
   ```yaml
   # config/shakapacker.yml
   default: &default
     bundler: 'rspack'
   ```

3. **Create Rspack config:**
   ```javascript
   // config/rspack/rspack.config.js
   const { generateRspackConfig } = require('shakapacker/rspack')
   module.exports = generateRspackConfig()
   ```

4. **Remove CoffeeScript files** (if any) - not supported by Rspack

5. **Test your application** - same commands work automatically

## Troubleshooting

### Configuration Issues

If you encounter configuration issues:

1. Check that all plugins are Rspack-compatible
2. Verify custom loaders work with Rspack
3. Review the [Rspack migration guide](https://rspack.rs/guide/migration/webpack)

### Performance Issues

If builds are unexpectedly slow:

1. Ensure you're using built-in Rspack loaders
2. Check for webpack-specific plugins that should be replaced
3. Review your asset optimization settings

## Further Reading

- [Rspack Official Documentation](https://rspack.rs)
- [Rspack Migration Guide](https://rspack.rs/guide/migration/webpack)
- [Rspack Plugins](https://rspack.rs/plugins/webpack/)