# Configuration Diff Tool

Shakapacker includes a semantic configuration diff workflow for webpack/rspack configs via [`pack-config-diff`](https://github.com/shakacode/pack-config-diff).

This gives you structured, meaningful diffs instead of raw line-by-line file diffs.

Use this during webpack-to-Rspack migrations whenever you need to confirm that a generated or hand-rolled rspack config preserved the important behavior of the old webpack config. It is especially useful before deleting a custom webpack builder, changing SSR/client split configs, or replacing plugin chains.

## Why use this instead of `diff`?

Traditional file diff tools are great for source code, but generated bundler configs are noisy and deeply nested.

Semantic diffing is better for this use case because it:

- Understands nested webpack/rspack configuration objects
- Supports filtering noisy sections with `--ignore-keys` and `--ignore-paths`
- Normalizes machine-specific absolute paths by default
- Supports summary, detailed, JSON, and YAML output formats
- Handles config-specific value types (functions, RegExp, Date)

## Quick Start

Export configs, then diff them:

```bash
# Export all standard configs (dev/prod + client/server)
bin/shakapacker-config --doctor

# Compare development vs production client config
bin/diff-bundler-config \
  --left=shakapacker-config-exports/webpack-development-client.yml \
  --right=shakapacker-config-exports/webpack-production-client.yml
```

## Common Workflows

### 1. Works in development, broken in production

```bash
bin/shakapacker-config --doctor

bin/diff-bundler-config \
  --left=shakapacker-config-exports/webpack-development-client.yml \
  --right=shakapacker-config-exports/webpack-production-client.yml \
  --format=summary
```

### 2. Compare client vs server bundles

```bash
bin/shakapacker-config --doctor

bin/diff-bundler-config \
  --left=shakapacker-config-exports/webpack-production-client.yml \
  --right=shakapacker-config-exports/webpack-production-server.yml
```

### 3. Webpack to Rspack migration validation

```bash
# Export webpack state
bin/shakapacker-config --doctor

# Switch bundler
bundle exec rake shakapacker:switch_bundler rspack --install-deps

# Export rspack state
bin/shakapacker-config --doctor

# Compare two snapshots (rename or copy files as needed)
bin/diff-bundler-config \
  --left=webpack-production-client.yml \
  --right=rspack-production-client.yml \
  --ignore-paths="plugins.*"
```

Run this comparison for each important build target, such as development client, production client, and SSR/server bundles. Start with `--format=summary`, then rerun without it for detailed paths when the summary shows a behavioral difference you did not expect.

### 4. Capture machine-readable report for CI or PR artifacts

```bash
bin/diff-bundler-config \
  --left=baseline.yaml \
  --right=current.yaml \
  --format=json \
  --output=config-diff.json
```

## Output Formats

```bash
# Detailed (default)
bin/diff-bundler-config --left=a.yaml --right=b.yaml --format=detailed

# Summary
bin/diff-bundler-config --left=a.yaml --right=b.yaml --format=summary

# JSON
bin/diff-bundler-config --left=a.yaml --right=b.yaml --format=json

# YAML
bin/diff-bundler-config --left=a.yaml --right=b.yaml --format=yaml
```

## Useful Options

```bash
# Include unchanged values
--include-unchanged

# Limit recursion depth
--max-depth=5

# Ignore keys globally
--ignore-keys=timestamp,version

# Ignore paths (supports wildcards)
--ignore-paths="plugins.*,output.path"

# Disable automatic path normalization
--no-normalize-paths
```

## Supported Input Files

- JSON (`.json`)
- YAML (`.yaml`, `.yml`)
- JavaScript (`.js`)
- TypeScript (`.ts`, requires `ts-node`)

## Exit Codes

- `0`: no differences found
- `1`: differences found
- `2`: wrapper/runtime error (module load error, invalid return code)

For CI usage, treat `1` as "configs differ" and `2` as "tool/runtime failure".

## Programmatic Usage

You can use the package directly in scripts:

```js
const { DiffEngine, DiffFormatter } = require("pack-config-diff")

const engine = new DiffEngine({
  ignorePaths: ["plugins.*"]
})

const result = engine.compare(leftConfig, rightConfig, {
  leftFile: "webpack.dev.js",
  rightFile: "webpack.prod.js"
})

const formatter = new DiffFormatter()
console.log(formatter.formatDetailed(result))
```

## See Also

- [Troubleshooting Guide](./troubleshooting.md)
- [Rspack Migration Guide](./rspack_migration_guide.md)
- [pack-config-diff repository](https://github.com/shakacode/pack-config-diff)
