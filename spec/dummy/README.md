# Shakapacker Test Application

This is a test Rails application used for testing Shakapacker with different asset bundlers.

## Bundler Support

This dummy application supports testing with both Webpack and RSpack bundlers.

### Testing with Webpack (Default)

```bash
# Use webpack (default configuration)
bin/shakapacker
bin/shakapacker-dev-server
```

### Testing with RSpack

```bash
# Switch to RSpack configuration
bin/test-bundler rspack

# Then run shakapacker commands
bin/shakapacker
bin/shakapacker-dev-server

# Or run directly with the test-bundler script
bin/test-bundler rspack bin/shakapacker
```

### Switching Between Bundlers

The `bin/test-bundler` script allows you to easily switch between webpack and rspack configurations:

```bash
# Switch to rspack
bin/test-bundler rspack

# Switch back to webpack
bin/test-bundler webpack

# Run a command with a specific bundler
bin/test-bundler rspack bin/shakapacker
bin/test-bundler webpack bin/shakapacker-dev-server
```

## Configuration Files

- `config/shakapacker.yml` - Active configuration (modified by test-bundler script)
- `config/shakapacker-webpack.yml` - Webpack-specific configuration
- `config/shakapacker-rspack.yml` - RSpack-specific configuration
- `config/webpack/webpack.config.js` - Webpack configuration
- `config/rspack/rspack.config.js` - RSpack configuration

## Environment Variables

You can also use environment variables to override the bundler:

```bash
SHAKAPACKER_ASSET_BUNDLER=rspack bin/shakapacker
SHAKAPACKER_ASSET_BUNDLER=webpack bin/shakapacker
```

## Running Tests

To test both bundlers in CI or locally:

```bash
# Test with webpack
bin/test-bundler webpack bin/shakapacker
# Run your tests here

# Test with rspack
bin/test-bundler rspack bin/shakapacker
# Run your tests here
```