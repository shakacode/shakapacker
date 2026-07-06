# Shakapacker v10 Upgrade Guide

This guide covers intentional breaking changes and common upgrade issues when
moving from Shakapacker v9 to v10.

If your app is still on Shakapacker v8 or earlier, apply the
[v9 upgrade guide](./v9_upgrade.md) first. The v9 CSS Modules and SWC changes
still matter for apps that skipped a major version.

**For the standard gem and npm update steps, see
[Upgrading Shakapacker](./common-upgrades.md#upgrading-shakapacker).**

> **Important:** Shakapacker is both a Ruby gem and an npm package. Update both
> sides together:
>
> - Update the gem version in `Gemfile`.
> - Update the npm package version in `package.json`.
> - Run `bundle update shakapacker`.
> - Run your package manager install command (`yarn install`, `npm install`,
>   `pnpm install`, or `bun install`).

## Summary

| Change                                                                                  | Introduced                         | Symptom                                                                                          | Fix                                                                                                |
| --------------------------------------------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| Webpack minimum is `^5.101.0`; webpack-dev-server v4 is no longer supported             | v10.0.0                            | Peer dependency errors, install conflicts, or dev-server schema errors                           | Upgrade `webpack` and `webpack-dev-server`; replace deprecated dev-server middleware hooks         |
| Node engine now requires Node 20.19+ or 22.12+                                          | v10.1.0                            | `engines.node` failures with `--engine-strict`, workspaces, or CI on Node 20.0-20.18 or 21.x     | Upgrade local, CI, and deploy Node versions                                                        |
| Native ESM named imports of lazy `baseConfig` and `rules` no longer work                | v10.1.0                            | `SyntaxError` while importing `baseConfig` or `rules` from `shakapacker` or `shakapacker/rspack` | Use the default import and read properties from it                                                 |
| Rspack support targets the Rspack v2 stack                                              | v10.2.0                            | Rspack peer conflicts, old React Refresh constructor errors, or stale v1 config assumptions      | Upgrade Rspack packages and custom config snippets to v2-compatible forms                          |
| Unset webpack transpiler config can still surface SWC loader issues during v10 upgrades | v9 behavior, commonly hit in v10.2 | `Your Shakapacker config specified using swc, but swc-loader package is not installed.`          | Set `javascript_transpiler` explicitly and install the matching Babel or SWC packages              |
| Optional supplemental package adoption can require adjacent dependency updates          | v10.1.0                            | Package-manager peer conflicts after switching to `shakapacker-webpack` or `shakapacker-rspack`  | Follow the v10.1 supplemental package migration guide and keep directly imported packages explicit |

## 1. Update Webpack and webpack-dev-server

### Symptom

You may see package manager peer dependency errors, failed installs, or
webpack-dev-server configuration errors after updating to Shakapacker 10.

### Cause

Shakapacker 10.0 raised the minimum supported webpack stack:

- `webpack` must satisfy `^5.101.0`.
- `webpack-dev-server` must satisfy `^5.2.2` or newer.
- webpack-dev-server v4 is no longer supported.
- webpack-dev-server v5 ignores the old `on_before_setup_middleware` and
  `on_after_setup_middleware` hooks.

Shakapacker also supports `webpack-dev-server` v6 on the current v10 line.

### Fix

Update your webpack packages together:

```bash
yarn add --dev webpack@^5.101.0 webpack-dev-server@^5.2.2
# or
npm install --save-dev webpack@^5.101.0 webpack-dev-server@^5.2.2
# or
pnpm add --save-dev webpack@^5.101.0 webpack-dev-server@^5.2.2
```

If your custom dev-server config uses deprecated middleware hooks, move that
logic to `setup_middlewares`.

See the [webpack-dev-server troubleshooting notes](./troubleshooting.md#webpack-or-webpack-dev-server-not-found)
and [PR #1021](https://github.com/shakacode/shakapacker/pull/1021).

## 2. Upgrade Node

### Symptom

Package managers fail with an engine error when `--engine-strict` is enabled, in
workspaces, or in CI. The common failing ranges are Node 20.0.0 through 20.18.x
and Node 21.x.

### Cause

Shakapacker 10.1 tightened `package.json` `engines.node` to
`^20.19.0 || >=22.12.0` to match the supported Rspack v2 ecosystem.

### Fix

Use Node `20.19.0` or newer on the Node 20 line, or Node `22.12.0` or newer on
the Node 22+ line. Update local version files, CI images, and deploy images
together so the same engine range is used everywhere.

See [PR #1099](https://github.com/shakacode/shakapacker/pull/1099).

## 3. Replace Native ESM Named Imports of `baseConfig` and `rules`

### Symptom

Native ESM config files fail at load time with an error similar to:

```text
SyntaxError: Named export 'baseConfig' not found
```

The same applies to `rules`.

### Cause

Shakapacker 10.1 made `baseConfig` and `rules` lazy CommonJS getters to avoid
loading bundler plugins as a side effect. Node cannot statically detect those
two lazy CommonJS properties as native ESM named exports.

Other named imports such as `config`, `env`, `merge`, `generateWebpackConfig`,
and `generateRspackConfig` are still explicitly exported.

### Fix

Use a default import and read the lazy properties from that object:

```javascript
// Before
import { baseConfig, rules } from "shakapacker"

// After
import shakapacker from "shakapacker"

const { baseConfig, rules } = shakapacker
```

For Rspack:

```javascript
import shakapackerRspack from "shakapacker/rspack"

const { baseConfig, rules } = shakapackerRspack
```

CommonJS access continues to work:

```javascript
const { baseConfig, rules } = require("shakapacker")
```

See [PR #1107](https://github.com/shakacode/shakapacker/pull/1107).

## 4. Move Rspack Apps to the Rspack v2 Stack

### Symptom

Rspack apps may hit peer dependency conflicts, `@rspack/plugin-react-refresh`
constructor errors, or dev-server behavior that does not match older Rspack v1
examples.

### Cause

Shakapacker 10.2 targets Rspack v2:

- `@rspack/core`, `@rspack/cli`, and `@rspack/dev-server` use v2 ranges.
- `rspack-manifest-plugin` must satisfy `^5.2.2`.
- `@rspack/plugin-react-refresh` uses the v2 named
  `ReactRefreshRspackPlugin` export.
- `css-loader` must satisfy `^7.1.4` when your Rspack build uses
  Shakapacker-managed CSS loader rules.
- Rspack v2 uses top-level `lazyCompilation`; Shakapacker disables it for the
  split Rails dev-server topology unless you explicitly configure a safe value.

### Fix

Update the managed Rspack stack together:

```bash
yarn add --dev @rspack/core@^2 @rspack/cli@^2 @rspack/dev-server@^2 rspack-manifest-plugin@^5.2.2 @rspack/plugin-react-refresh@^2 css-loader@^7.1.4
# or
npm install --save-dev @rspack/core@^2 @rspack/cli@^2 @rspack/dev-server@^2 rspack-manifest-plugin@^5.2.2 @rspack/plugin-react-refresh@^2 css-loader@^7.1.4
# or
pnpm add --save-dev @rspack/core@^2 @rspack/cli@^2 @rspack/dev-server@^2 rspack-manifest-plugin@^5.2.2 @rspack/plugin-react-refresh@^2 css-loader@^7.1.4
```

If you use React Refresh in a custom Rspack config, use the v2 named export:

```javascript
const { ReactRefreshRspackPlugin } = require("@rspack/plugin-react-refresh")
```

For config that must tolerate both v1 and v2 while you migrate:

```javascript
const reactRefreshModule = require("@rspack/plugin-react-refresh")
const ReactRefreshPlugin =
  reactRefreshModule.ReactRefreshRspackPlugin ||
  reactRefreshModule.default ||
  reactRefreshModule

module.exports = {
  plugins: [new ReactRefreshPlugin()]
}
```

Issue [#1204](https://github.com/shakacode/shakapacker/issues/1204) tracks the
10.2.1 doctor warning for old custom React Refresh config patterns. See also
[PR #1179](https://github.com/shakacode/shakapacker/pull/1179), the
[Rspack guide](./rspack.md), and the
[Rspack migration guide](./rspack_migration_guide.md).

## 5. Set `javascript_transpiler` Explicitly for Webpack Apps

### Symptom

Webpack apps that upgraded across major versions can fail before compilation
with:

```text
Your Shakapacker config specified using swc, but swc-loader package is not installed.
```

This is most common for apps that use Babel, do not have `swc-loader`, and do
not set either `javascript_transpiler` or the deprecated `webpack_loader` key in
their own `config/shakapacker.yml`.

### Cause

Shakapacker v9 switched new installs to SWC. Apps that skipped the v9 migration
work or trimmed their config can discover that implicit SWC default during a
10.x upgrade even though the app still has Babel dependencies.

### Fix

Set the transpiler intentionally in `config/shakapacker.yml`.

For Babel:

```yaml
default: &default
  javascript_transpiler: babel
```

For SWC:

```yaml
default: &default
  javascript_transpiler: swc
```

Then install the matching package set:

```bash
# Babel
yarn add --dev @babel/core @babel/plugin-transform-runtime @babel/preset-env babel-loader
yarn add @babel/runtime

# SWC
yarn add --dev @swc/core swc-loader
```

Issue [#1203](https://github.com/shakacode/shakapacker/issues/1203) tracks
compatibility work for this upgrade path. Do not rely on automatic fallback
behavior unless your installed Shakapacker release notes explicitly include it;
set `javascript_transpiler` in your app config.

If you skipped v9, also review
[SWC is Now the Default JavaScript Transpiler](./v9_upgrade.md#3-swc-is-now-the-default-javascript-transpiler).

## 6. Adopt Supplemental Packages Deliberately

### Symptom

After switching to `shakapacker-webpack` or `shakapacker-rspack`, package
managers may report peer conflicts or missing direct dependencies in pnpm or
Yarn PnP projects.

### Cause

The supplemental packages added in 10.1 are opt-in wrappers around the managed
build stack. They intentionally keep `shakapacker` lockstep-pinned and declare
the bundler stack through package-manager dependency rules. That simplifies many
apps, but it does not remove dependencies that your app's own config imports
directly.

`shakapacker-webpack` also requires `webpack-assets-manifest@^6.0.0`.

### Fix

Use the supplemental packages only when they simplify your dependency graph, and
keep directly imported packages explicit for pnpm and Yarn PnP.

Follow the
[v10.1 supplemental packages migration guide](./migration/v10.1-supplemental-packages.md)
for before/after `package.json` examples.

## Migration Checklist

1. Update both the gem and npm package.
2. Confirm Node is `^20.19.0 || >=22.12.0`.
3. If using webpack, update `webpack` and `webpack-dev-server`.
4. If using Rspack, update the full Rspack v2 stack.
5. Set `javascript_transpiler` explicitly for webpack apps.
6. Replace native ESM named imports of `baseConfig` or `rules`.
7. Review custom React Refresh config for the Rspack v2 named export.
8. Run a local build:

   ```bash
   bin/shakapacker
   bin/shakapacker-dev-server
   ```

9. Run your app's test suite and deploy to staging before production.
