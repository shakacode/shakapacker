# Duplicate Configuration Documentation Analysis

This document identifies duplicate configuration documentation that could be consolidated to refer to the new comprehensive [Configuration Guide](docs/configuration.md).

## README.md Duplicates

### 1. `nested_entries` Explanation (Line 354)

**Current duplicate content:**

```markdown
`nested_entries` allows you to have webpack entry points nested in subdirectories. This defaults to true as of shakapacker v7. With `nested_entries: false`, you can have your entire `source_path` used for your source (using the `source_entry_path: /`) and you place files at the top level that you want as entry points. `nested_entries: true` allows you to have entries that are in subdirectories. This is useful if you have entries that are generated, so you can have a `generated` subdirectory and easily separate generated files from the rest of your codebase.
```

**Recommendation:**
Replace with brief description + link to Configuration Guide:

```markdown
`nested_entries` allows webpack entry points in subdirectories (defaults to `true`). For details, see [nested_entries in the Configuration Guide](docs/configuration.md#nested_entries).
```

**Reason:** The Configuration Guide has the same information plus more context.

---

### 2. `useContentHash` Explanation (Line 356)

**Current duplicate content:**

```markdown
To enable/disable the usage of contentHash in any node environment (specified using the `NODE_ENV` environment variable), add/modify `useContentHash` with a boolean value in `config/shakapacker.yml`. This feature is disabled for all environments except production by default. You may not disable the content hash for a `NODE_ENV` of production as that would break the browser caching of assets. Notice that despite the possibility of enabling this option for the development environment, [it is not recommended](https://webpack.js.org/guides/build-performance/#avoid-production-specific-tooling).
```

**Recommendation:**
Replace with:

```markdown
The `useContentHash` option controls content-based cache busting. It's disabled by default (except production) as it slows development builds. For details, see [useContentHash in the Configuration Guide](docs/configuration.md#usecontenthash).
```

**Reason:** The Configuration Guide covers this comprehensively.

---

### 3. `compiler_strategy` Explanation (Line 608)

**Current duplicate content:**

```markdown
You can control what strategy is used by the `compiler_strategy` option in `shakapacker.yml` config file. By default `mtime` strategy is used in development environment, `digest` is used elsewhere.
```

**Recommendation:**
Replace with:

```markdown
The `compiler_strategy` option determines how freshness is checked (`mtime` for development, `digest` for production). See [compiler_strategy in the Configuration Guide](docs/configuration.md#compiler_strategy) for details.
```

**Reason:** Better explained in the Configuration Guide with pros/cons.

---

### 4. `SHAKAPACKER_CONFIG` Environment Variable (Line 375)

**Current duplicate content:**

```markdown
#### Setting custom config path

You can use the environment variable `SHAKAPACKER_CONFIG` to enforce a particular path to the config file rather than the default `config/shakapacker.yml`.
```

**Recommendation:**
Consolidate into Configuration Guide section, replace with:

```markdown
#### Setting custom config path

See [Environment Variables in the Configuration Guide](docs/configuration.md#environment-variables) for `SHAKAPACKER_CONFIG` and other options.
```

**Reason:** Configuration Guide has comprehensive environment variables table.

---

### 5. Precompile Hook Section (Lines 358-371)

**Current content:**

````markdown
#### Precompile Hook

Shakapacker supports running a custom command before webpack compilation via the `precompile_hook` configuration option. This is useful for:

- Dynamically generating entry points (e.g., React on Rails `generate_packs`)
- Running preparatory tasks before asset compilation in both development and production

```yaml
# Works in all environments (development, production)
default: &default
  precompile_hook: "bin/rails react_on_rails:generate_packs"
```
````

For complete documentation including React on Rails integration, security features, and troubleshooting, see the [Precompile Hook Guide](docs/precompile_hook.md).

````

**Recommendation:**
Keep brief intro, but also link to Configuration Guide:
```markdown
#### Precompile Hook

Shakapacker supports running custom commands before compilation via `precompile_hook`.

For configuration details, see [precompile_hook in the Configuration Guide](docs/configuration.md#precompile_hook).
For complete usage guide, see the [Precompile Hook Guide](docs/precompile_hook.md).
````

**Reason:** Directs users to both configuration reference and usage guide.

---

## Summary of Recommendations

### High Priority Consolidations (Clear Duplicates)

1. **nested_entries** - Full explanation duplicated
2. **useContentHash** - Full explanation duplicated
3. **compiler_strategy** - Explanation duplicated
4. **SHAKAPACKER_CONFIG** - Should reference env vars table

### Medium Priority (Partial Duplicates)

5. **Precompile Hook** - Add Configuration Guide link alongside existing link

### Benefits of Consolidation

1. **Single Source of Truth** - Configuration options documented in one place
2. **Easier Maintenance** - Updates only needed in Configuration Guide
3. **Better Discoverability** - Users learn about the comprehensive guide
4. **Reduced README Length** - Makes README more scannable

### Implementation Strategy

1. Keep brief 1-2 sentence summaries in README
2. Link to Configuration Guide for details
3. Preserve links to specialized guides (e.g., Precompile Hook Guide)
4. Ensure Configuration Guide has anchor links for each option
