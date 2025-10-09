# Configuration Diff Tool

Shakapacker provides a powerful configuration diff tool to help you compare webpack/rspack configurations and identify differences. This is particularly useful for:

- Comparing development vs production configurations
- Debugging configuration issues
- Understanding what changed between environments
- Analyzing differences between client and server bundles

## Quick Start

Compare two exported configuration files:

```bash
bin/diff-bundler-config \
  --left=webpack-development-client.yaml \
  --right=webpack-production-client.yaml
```

## Usage

### Basic Comparison

First, export your configurations using the [config exporter](../README.md#exporting-configuration):

```bash
# Export development configs
bin/export-bundler-config --save --env=development

# Export production configs
bin/export-bundler-config --save --env=production
```

Then compare them:

```bash
bin/diff-bundler-config \
  --left=webpack-development-client.yaml \
  --right=webpack-production-client.yaml
```

### Output Formats

The diff tool supports multiple output formats:

#### Detailed (default)

Shows a comprehensive report with all changes grouped by operation type:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --format=detailed
```

#### Summary

Shows only counts of changes:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --format=summary
```

#### JSON

Machine-readable format for programmatic processing:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --format=json \
  --output=diff-report.json
```

#### YAML

Structured YAML format:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --format=yaml
```

## Advanced Options

### Ignoring Specific Keys

Ignore certain keys across all levels:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --ignore-keys=timestamp,version
```

### Ignoring Paths

Ignore specific paths in the configuration tree (supports wildcards):

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --ignore-paths="plugins.*,output.path"
```

### Including Unchanged Values

By default, only changes are shown. To include unchanged values:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --include-unchanged
```

### Controlling Depth

Limit comparison depth to avoid deeply nested structures:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --max-depth=5
```

### Path Normalization

By default, absolute paths are normalized to relative paths for easier comparison. To disable:

```bash
bin/diff-bundler-config \
  --left=config1.yaml \
  --right=config2.yaml \
  --no-normalize-paths
```

## Supported File Formats

The diff tool can compare files in the following formats:

- **JSON** (`.json`)
- **YAML** (`.yaml`, `.yml`)
- **JavaScript** (`.js`) - requires the file to export a config object
- **TypeScript** (`.ts`) - requires `ts-node` to be installed

## Complete Command Reference

```
bin/diff-bundler-config --left=<file1> --right=<file2> [options]

Required:
  --left=<file>              First (left) config file to compare
  --right=<file>             Second (right) config file to compare

Output:
  --format=<format>          Output format: detailed, summary, json, yaml
                             (default: detailed)
  --output=<file>            Write output to file instead of stdout

Comparison:
  --include-unchanged        Include unchanged values in output
  --max-depth=<number>       Maximum depth for comparison (default: unlimited)
  --ignore-keys=<keys>       Comma-separated list of keys to ignore
  --ignore-paths=<paths>     Comma-separated list of paths to ignore
  --no-normalize-paths       Disable automatic path normalization
  --path-separator=<sep>     Path separator for display (default: ".")

Help:
  --help, -h                 Show help message
```

## Exit Codes

- `0` - Success, no differences found
- `1` - Differences found or error occurred

This allows you to use the diff tool in CI/CD pipelines:

```bash
# Fail if configs differ
bin/diff-bundler-config --left=expected.yaml --right=actual.yaml || exit 1
```

## Programmatic Usage

You can also use the diff engine programmatically in your own scripts:

```javascript
const { DiffEngine } = require("shakapacker/configDiffer")

const engine = new DiffEngine({
  includeUnchanged: false,
  ignoreKeys: ["timestamp"],
  format: "json"
})

const result = engine.compare(config1, config2)

console.log(`Found ${result.summary.totalChanges} changes`)
```

## Examples

### Compare Development vs Production

```bash
# Export both environments
bin/export-bundler-config --doctor

# Compare client configs
bin/diff-bundler-config \
  --left=shakapacker-config-exports/webpack-development-client.yaml \
  --right=shakapacker-config-exports/webpack-production-client.yaml \
  --format=summary
```

### Find What Changed in a Migration

```bash
# Export old config
bin/export-bundler-config --save --output=config-old.yaml

# Make your changes...

# Export new config
bin/export-bundler-config --save --output=config-new.yaml

# See what changed
bin/diff-bundler-config \
  --left=config-old.yaml \
  --right=config-new.yaml
```

### Generate JSON Report for CI

```bash
bin/diff-bundler-config \
  --left=baseline.json \
  --right=current.json \
  --format=json \
  --output=diff-report.json
```

## Tips

1. **Use `--format=summary` first** to get a quick overview before diving into details
2. **Ignore timestamps and non-deterministic values** using `--ignore-keys`
3. **Normalize paths** (enabled by default) to make diffs more readable
4. **Save diffs to files** for later reference or sharing with your team
5. **Use wildcards** in `--ignore-paths` to ignore entire sections (e.g., `plugins.*`)

## See Also

- [Configuration Export Tool](../README.md#exporting-configuration)
- [Troubleshooting Guide](troubleshooting.md)
