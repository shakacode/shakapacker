# Shakapacker Configuration Guide

This guide covers all configuration options available in `config/shakapacker.yml` and how to use them effectively.

## Table of Contents

- [Basic Configuration](#basic-configuration)
- [Source Configuration](#source-configuration)
- [Output Configuration](#output-configuration)
- [Bundler Configuration](#bundler-configuration)
- [Development Server](#development-server)
- [Compilation Options](#compilation-options)
- [Advanced Options](#advanced-options)
  - [Subresource Integrity](#integrity)
  - [Early Hints](#early_hints)
- [Environment-Specific Configuration](#environment-specific-configuration)

## Basic Configuration

### `assets_bundler`

**Type:** `string`
**Default:** `"webpack"`
**Options:** `"webpack"` or `"rspack"`

Specifies which bundler to use for compiling assets.

```yaml
# Use webpack (default)
assets_bundler: "webpack"

# Use rspack for faster builds
assets_bundler: "rspack"
```

See [RSpack Migration Guide](rspack_migration_guide.md) for details on switching bundlers.

### `assets_bundler_config_path`

**Type:** `string`
**Default:** `"config/webpack"` for webpack, `"config/rspack"` for rspack

Specifies the directory containing your webpack/rspack config files.

```yaml
# Use default paths (config/webpack or config/rspack)
# assets_bundler_config_path: config/webpack

# Use custom directory
assets_bundler_config_path: "build_configs"

# Use project root directory
assets_bundler_config_path: "."
```

**When to use:**

- When migrating from another build tool and want to preserve existing config locations
- When organizing configs in a monorepo structure
- When following custom project conventions

### `javascript_transpiler`

**Type:** `string`
**Default:** `"swc"` (or `"babel"` for webpack when not specified)
**Options:** `"swc"`, `"babel"`, or `"esbuild"`

Specifies which transpiler to use for JavaScript/TypeScript.

```yaml
# Use SWC (recommended - 20x faster than Babel)
javascript_transpiler: "swc"

# Use Babel (for maximum compatibility)
javascript_transpiler: "babel"

# Use esbuild (fastest, but may have compatibility issues)
javascript_transpiler: "esbuild"
```

**Note:** When using rspack, swc is used automatically regardless of this setting due to built-in support.

See [Transpiler Performance Guide](transpiler-performance.md) for benchmarks and migration guides.

## Source Configuration

### `source_path`

**Type:** `string`
**Default:** `"app/javascript"`

The root directory for your JavaScript source files.

```yaml
# Default
source_path: app/javascript

# Custom location
source_path: app/frontend
```

### `source_entry_path`

**Type:** `string`
**Default:** `"packs"`

Subdirectory within `source_path` containing entry points.

```yaml
# Recommended: use a subdirectory
source_entry_path: packs

# Use the entire source_path as entry directory
source_entry_path: /
```

**Note:** Cannot use `/` when `nested_entries` is `true`.

### `nested_entries`

**Type:** `boolean`
**Default:** `true`

Whether to automatically discover entry points in subdirectories within `source_entry_path`.

```yaml
# Enable nested entries (recommended)
nested_entries: true

# Disable - only top-level files are entries
nested_entries: false
```

**Example with nested entries:**

```
app/javascript/packs/
  application.js       # Entry: application
  admin/
    dashboard.js       # Entry: admin/dashboard
```

### `additional_paths`

**Type:** `array`
**Default:** `[]`

Additional directories for webpack/rspack to search for modules.

```yaml
additional_paths:
  - app/assets
  - vendor/assets
  - node_modules/legacy-lib
```

**Use cases:**

- Resolving modules from Rails asset directories
- Including vendored JavaScript
- Sharing code between engines

## Output Configuration

### `public_root_path`

**Type:** `string`
**Default:** `"public"`

The public directory where assets are served from.

```yaml
public_root_path: public
```

### `public_output_path`

**Type:** `string`
**Default:** `"packs"`

Subdirectory within `public_root_path` for compiled assets.

```yaml
# Default - outputs to public/packs
public_output_path: packs

# Custom output directory
public_output_path: webpack-bundles
```

### `private_output_path`

**Type:** `string`
**Default:** `nil`

Directory for private server-side bundles (e.g., for SSR) that should not be publicly accessible.

```yaml
# Enable private output for SSR bundles
private_output_path: ssr-generated
```

**Important:** Must be different from `public_output_path` to prevent serving private bundles.

### `manifest_path`

**Type:** `string`
**Default:** `"{public_output_path}/manifest.json"`

Location of the manifest.json file that maps entry points to compiled assets.

```yaml
# Custom manifest location
manifest_path: public/assets/webpack-manifest.json
```

**Note:** Rarely needs to be changed from the default.

### `cache_path`

**Type:** `string`
**Default:** `"tmp/shakapacker"`

Directory for webpack/rspack cache files.

```yaml
cache_path: tmp/shakapacker

# Use a shared cache in CI
cache_path: /mnt/shared/webpack-cache
```

## Bundler Configuration

### `webpack_compile_output`

**Type:** `boolean`
**Default:** `true`

Whether to show webpack/rspack compilation output in the console.

```yaml
# Show detailed output (helpful for debugging)
webpack_compile_output: true

# Minimal output (cleaner logs)
webpack_compile_output: false
```

### `useContentHash`

**Type:** `boolean`
**Default:** `false` (development), `true` (production - enforced)

Whether to include content hashes in asset filenames for cache busting.

```yaml
# Production only (default)
useContentHash: false

# Always use content hash (not recommended for development)
useContentHash: true
```

**Note:** In production, this is always `true` regardless of configuration.

### `css_extract_ignore_order_warnings`

**Type:** `boolean`
**Default:** `false`

Whether to suppress mini-css-extract-plugin order warnings.

```yaml
# Enable if you have consistent CSS scoping
css_extract_ignore_order_warnings: true
```

**When to enable:**

- When using CSS modules or scoped styles
- When following BEM or similar naming conventions
- When order warnings are false positives

## Development Server

### `dev_server`

Configuration for `bin/shakapacker-dev-server`. See [Dev Server Options](#dev-server-options) below.

#### Dev Server Options

```yaml
dev_server:
  # Host to bind to
  host: localhost

  # Port to listen on
  port: 3035

  # Enable HTTPS
  # server: https

  # Hot Module Replacement
  hmr: false

  # Live reload (alternative to HMR)
  # live_reload: true

  # Inline CSS with HMR (requires style-loader)
  inline_css: true

  # Compression
  compress: true

  # Allowed hosts (security)
  allowed_hosts: "auto"

  # Client configuration
  client:
    # Show error overlay
    overlay: true

    # Custom WebSocket URL
    # webSocketURL:
    #   hostname: '0.0.0.0'
    #   pathname: '/ws'
    #   port: 8080

  # Headers for CORS
  headers:
    "Access-Control-Allow-Origin": "*"

  # Static file serving
  static:
    watch:
      ignored: "**/node_modules/**"
```

**Key Options:**

- **hmr:** Hot Module Replacement updates modules without full reload. Requires additional setup.
- **inline_css:** With HMR, CSS is delivered via JavaScript. Set to `false` to use `<link>` tags.
- **overlay:** Shows errors/warnings in browser overlay. Helpful for development.
- **allowed_hosts:** Protects against DNS rebinding attacks. Use `"all"` to disable (not recommended).

## Compilation Options

### `compile`

**Type:** `boolean`
**Environment-specific**

Whether to compile assets on-demand when requests are made.

```yaml
development:
  compile: true # Compile on demand

production:
  compile: false # Assets must be precompiled
```

### `shakapacker_precompile`

**Type:** `boolean`
**Default:** `true`

Whether `rails assets:precompile` should compile webpack/rspack assets.

```yaml
# Include in assets:precompile (recommended)
shakapacker_precompile: true

# Skip webpack compilation during assets:precompile
shakapacker_precompile: false
```

**Override via environment variable:**

```bash
SHAKAPACKER_PRECOMPILE=false rails assets:precompile
```

### `cache_manifest`

**Type:** `boolean`
**Default:** `false` (development), `true` (production)

Whether to cache manifest.json in memory.

```yaml
development:
  cache_manifest: false # Reload on every request

production:
  cache_manifest: true # Cache for performance
```

### `compiler_strategy`

**Type:** `string`
**Default:** `"mtime"` (development), `"digest"` (production)
**Options:** `"mtime"` or `"digest"`

How to determine if assets need recompilation.

```yaml
development:
  # Fast: check file modification times
  compiler_strategy: mtime

production:
  # Accurate: check content hashes
  compiler_strategy: digest
```

**mtime:** Faster but may miss changes if timestamps are unreliable.
**digest:** Slower but guarantees accuracy by comparing content hashes.

## Advanced Options

### `precompile_hook`

**Type:** `string`
**Default:** `nil`

Command to run before webpack/rspack compilation. Useful for generating dynamic entry points.

```yaml
precompile_hook: "bin/shakapacker-precompile-hook"
```

**Security:** Only reference trusted scripts within your project. The path is validated.

See [Precompile Hook Guide](precompile_hook.md) for examples and use cases.

### `ensure_consistent_versioning`

**Type:** `boolean`
**Default:** `true`

Raises an error if shakapacker gem and npm package versions don't match.

```yaml
# Enforce version matching (recommended)
ensure_consistent_versioning: true

# Allow version mismatches (not recommended)
ensure_consistent_versioning: false
```

### `asset_host`

**Type:** `string`
**Default:** `nil` (uses Rails asset host)

Override Rails asset host for webpack assets specifically.

```yaml
# Use custom CDN for webpack assets
asset_host: https://cdn.example.com
```

**Environment variable override:**

```bash
SHAKAPACKER_ASSET_HOST=https://cdn.example.com
```

See [CDN Setup Guide](cdn_setup.md) for complete configuration.

### `integrity`

**Type:** `object`
**Default:** `{ enabled: false }`

Enable Subresource Integrity (SRI) for security.

```yaml
integrity:
  enabled: true
  hash_functions: ["sha384"] # or ["sha256"], ["sha512"]
  cross_origin: "anonymous" # or "use-credentials"
```

See [Subresource Integrity Guide](subresource_integrity.md) for details.

### `early_hints`

**Type:** `object`
**Default:** `{ enabled: false, include_css: true, include_js: true }`
**Requires:** Rails 5.2+, HTTP/2-capable server (Puma 5+, nginx 1.13+)

Enable HTTP 103 Early Hints for faster asset loading by sending Link headers before the final response.

```yaml
early_hints:
  enabled: true # default: false - must be explicitly enabled
  include_css: true # default: true - send Link headers for CSS chunks
  include_js: true # default: true - send Link headers for JS chunks
```

**How it works:**
Browser starts downloading assets while Rails is still rendering, improving perceived page load performance.

**Configuration options:**

- **`enabled`**: Master switch for early hints feature (default: `false`)
  - Set to `true` in production for faster page loads
  - Keep `false` in development (minimal benefit, adds noise to logs)
- **`include_css`**: Preload CSS assets (default: `true` when enabled)
  - Set to `false` to skip CSS early hints (save bandwidth)
  - Only has effect if your packs actually include CSS files
  - If no CSS in manifest, this setting doesn't matter
- **`include_js`**: Preload JavaScript assets (default: `true` when enabled)
  - Set to `false` to skip JS early hints (rare use case)
  - Most apps should keep this `true`

**Common configurations:**

```yaml
# Recommended: Enable for production
production:
  early_hints:
    enabled: true
    include_css: true
    include_js: true

# Development: Disabled (default)
development:
  early_hints:
    enabled: false

# Mixed asset sources: Shakapacker has both JS and CSS
# But you only want early hints for JS (save bandwidth)
production:
  early_hints:
    enabled: true
    include_css: false  # Skip CSS early hints
    include_js: true    # Only preload JS
```

**Note:** If your Shakapacker packs have no CSS at all, setting `include_css: false` has no effect (nothing to skip). This is only useful if you have CSS in Shakapacker but choose not to preload it.

**Requirements:**

- Rails 5.2+ (for `request.send_early_hints` support)
- HTTP/2-capable web server (Puma 5+, nginx 1.13+)
- Modern browser (Chrome/Edge/Firefox 103+, Safari 16.4+)

**Graceful degradation:** Feature automatically disables if server or browser doesn't support it.

See [Early Hints Guide](EARLY_HINTS.md) for implementation and usage examples.

## Environment-Specific Configuration

Shakapacker supports per-environment configuration with fallback logic:

1. Checks for environment-specific config (e.g., `development`, `staging`)
2. Falls back to `production` if not found
3. Uses bundled defaults if neither exists

```yaml
# Shared defaults
default: &default
  source_path: app/javascript
  assets_bundler: "webpack"

# Development
development:
  <<: *default
  compile: true
  compiler_strategy: mtime
  dev_server:
    hmr: true

# Test
test:
  <<: *default
  compile: true
  public_output_path: packs-test

# Production
production:
  <<: *default
  compile: false
  cache_manifest: true
  compiler_strategy: digest
  useContentHash: true # Enforced regardless
```

### Custom Environments

For custom environments (e.g., `staging`), define a section or let it fall back to production:

```yaml
# Option 1: Explicit staging config
staging:
  <<: *default
  compile: false
  # staging-specific options

# Option 2: Let staging fall back to production
# (no staging section needed)
```

## Configuration Validation

Shakapacker validates configuration at runtime and provides helpful error messages:

- **Missing config files:** Suggests creating config or checking `assets_bundler_config_path`
- **Transpiler mismatch:** Warns if package.json dependencies don't match configured transpiler
- **Path conflicts:** Prevents `private_output_path` from being the same as `public_output_path`
- **Version mismatches:** Detects gem/npm version differences when `ensure_consistent_versioning` is enabled

## Environment Variables

Some options can be overridden via environment variables:

| Variable                     | Description              | Example                   |
| ---------------------------- | ------------------------ | ------------------------- |
| `SHAKAPACKER_CONFIG`         | Path to shakapacker.yml  | `config/webpack.yml`      |
| `SHAKAPACKER_ASSETS_BUNDLER` | Override assets bundler  | `rspack`                  |
| `SHAKAPACKER_PRECOMPILE`     | Override precompile flag | `false`                   |
| `SHAKAPACKER_ASSET_HOST`     | Override asset host      | `https://cdn.example.com` |
| `NODE_ENV`                   | Node environment         | `production`              |
| `RAILS_ENV`                  | Rails environment        | `staging`                 |

## Best Practices

1. **Use default paths** unless you have a specific reason to change them
2. **Enable SWC transpiler** for faster builds (20x faster than Babel)
3. **Use rspack** for even faster builds if compatible with your setup
4. **Cache manifest** in production for better performance
5. **Enable integrity hashes** in production for security
6. **Keep development and production configs aligned** except for optimization settings
7. **Use content hashes** in production for proper cache busting
8. **Validate after changes** by running `bin/shakapacker` to ensure compilation works

## Common Configuration Patterns

### Fast Development Setup

```yaml
development:
  assets_bundler: "rspack"
  javascript_transpiler: "swc"
  compiler_strategy: mtime
  webpack_compile_output: true
  dev_server:
    hmr: true
    inline_css: true
```

### Production-Optimized

```yaml
production:
  assets_bundler: "rspack"
  javascript_transpiler: "swc"
  compiler_strategy: digest
  cache_manifest: true
  useContentHash: true
  integrity:
    enabled: true
```

### Monorepo Setup

```yaml
default: &default
  source_path: packages/frontend/src
  assets_bundler_config_path: build_configs/webpack
  additional_paths:
    - packages/shared
    - packages/ui-components
```

## Troubleshooting

If you encounter configuration issues:

1. **Check error messages** - they often suggest the fix
2. **Validate YAML syntax** - use a YAML validator to ensure proper formatting
3. **Review fallback behavior** - missing environment configs fall back to production
4. **Check environment variables** - they override config file settings
5. **Inspect manifest.json** - verify assets are being compiled correctly

See [Troubleshooting Guide](troubleshooting.md) for more help.

## Related Guides

- [RSpack Migration Guide](rspack_migration_guide.md)
- [Transpiler Performance Guide](transpiler-performance.md)
- [Deployment Guide](deployment.md)
- [CDN Setup Guide](cdn_setup.md)
- [Precompile Hook Guide](precompile_hook.md)
- [Early Hints Guide](EARLY_HINTS.md)
- [Subresource Integrity Guide](subresource_integrity.md)
- [Troubleshooting Guide](troubleshooting.md)
