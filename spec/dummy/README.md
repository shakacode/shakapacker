# Shakapacker Dummy Test Application

This is a Rails test application used for testing Shakapacker with both Webpack and RSpack bundlers.

## Dual Bundler Support

This application supports testing with both **Webpack** and **RSpack** bundlers, allowing us to ensure Shakapacker works correctly with either bundler.

## Quick Start

### Using Webpack (Default)

```bash
# Ensure webpack configuration is active
bin/test-bundler webpack

# Run the bundler
bin/shakapacker

# Start dev server
bin/shakapacker-dev-server
```

### Using RSpack

```bash
# Switch to RSpack configuration
bin/test-bundler rspack

# Run the bundler
bin/shakapacker

# Start dev server
bin/shakapacker-dev-server
```

## The `test-bundler` Script

The `bin/test-bundler` script is the primary tool for switching between bundlers:

```bash
# Switch to webpack
bin/test-bundler webpack

# Switch to rspack
bin/test-bundler rspack

# Switch and run a command
bin/test-bundler webpack bin/shakapacker
bin/test-bundler rspack yarn build
```

### How it Works

The script works by copying the appropriate configuration file:
- `config/shakapacker-webpack.yml` → `config/shakapacker.yml` (for Webpack)
- `config/shakapacker-rspack.yml` → `config/shakapacker.yml` (for RSpack)

## Configuration Files

### Bundler Configurations
- `config/shakapacker.yml` - Active configuration (modified by test-bundler)
- `config/shakapacker-webpack.yml` - Webpack-specific settings
- `config/shakapacker-rspack.yml` - RSpack-specific settings

### Build Configurations
- `config/webpack/webpack.config.js` - Webpack build configuration
- `config/rspack/rspack.config.js` - RSpack build configuration

## Key Differences

### Webpack Configuration
- Uses `assets_bundler: 'webpack'`
- Default transpiler: `babel`
- Dev server uses `hmr` option
- More mature, stable option

### RSpack Configuration
- Uses `assets_bundler: 'rspack'`
- Recommended transpiler: `swc` (faster)
- Dev server uses `hot` option
- Faster build times, experimental

## Environment Variables

You can also override the bundler using environment variables:

```bash
# Force webpack regardless of config
SHAKAPACKER_ASSET_BUNDLER=webpack bin/shakapacker

# Force rspack regardless of config
SHAKAPACKER_ASSET_BUNDLER=rspack bin/shakapacker
```

## Testing

### Run Tests with Webpack
```bash
bin/test-bundler webpack
bundle exec rspec
```

### Run Tests with RSpack
```bash
bin/test-bundler rspack
bundle exec rspec
```

### CI Testing
The CI automatically tests both bundlers in parallel. See `.github/workflows/test-bundlers.yml` for the configuration.

## Troubleshooting

### Missing Dependencies
If you get errors about missing packages after switching bundlers:

```bash
# Install all dependencies
yarn install

# Or specifically for rspack
yarn add @rspack/core @rspack/cli rspack-manifest-plugin
```

### Configuration Issues
If the app doesn't work after switching:

1. Check that the correct config is active:
   ```bash
   grep assets_bundler config/shakapacker.yml
   ```

2. Ensure the config files exist:
   ```bash
   ls -la config/shakapacker-*.yml
   ```

3. Reset to default (webpack):
   ```bash
   bin/test-bundler webpack
   ```

## Development Tips

- Always run `yarn install` after updating package.json
- Use `bin/test-bundler` to switch between bundlers consistently
- Test both bundlers before committing changes
- RSpack is faster for development but may have compatibility issues with some plugins