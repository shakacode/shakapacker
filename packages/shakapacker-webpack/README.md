# shakapacker-webpack

`shakapacker-webpack` is the supplemental package for Shakapacker's managed webpack build path. It pairs `shakapacker` with the exact webpack, loader, and plugin versions that Shakapacker currently supports for the standard webpack setup.

## Install

`shakapacker-webpack` ships `shakapacker`, `webpack`, `webpack-cli`, and `webpack-assets-manifest` as direct dependencies, so a single install pulls in the full managed build stack:

```sh
# yarn
yarn add --dev shakapacker-webpack

# npm
npm install --save-dev shakapacker-webpack

# pnpm
pnpm add --save-dev shakapacker-webpack
```

**At least one JavaScript transpiler pair is required** — the runtime emits `SHAKAPACKER_NO_TRANSPILER` if none resolves. For the default SWC path, install `@swc/core@1.15.33` and `swc-loader@0.2.7`. Babel (`@babel/core@7.29.0` + `babel-loader@10.1.1`) and esbuild (`esbuild@0.27.7` + `esbuild-loader@4.4.3`) are also supported when set via `javascript_transpiler:` in `config/shakapacker.yml`. For dev-server/HMR usage, install `webpack-dev-server@5.2.3`; webpack-dev-server 4.x remains part of the legacy core compatibility window, not the supplemental package's managed stack.

### Simplifying an existing webpack install

If your app already runs Shakapacker on webpack, you can drop the managed-build deps from your `package.json` — they come along with `shakapacker-webpack`:

**Before (v10.0):**

```json
{
  "devDependencies": {
    "shakapacker": "^10.0.0",
    "webpack": "^5.0.0",
    "webpack-cli": "^6.0.0",
    "webpack-assets-manifest": "^5.0.6"
  }
}
```

**After (v10.1+ with `shakapacker-webpack`):**

```json
{
  "devDependencies": {
    "shakapacker-webpack": "~10.1.0"
  }
}
```

Optional peers (transpilers, `webpack-dev-server`, `mini-css-extract-plugin`, CSS preprocessors, etc.) stay only if your app uses those features. Run `yarn install` (or the npm/pnpm equivalent) and the lockfile collapses to the bundled stack.

### Migrating from core's webpack peer set

Core `shakapacker` accepts both `webpack-assets-manifest` v5 and v6 (`^5.0.6 || ^6.0.0`). `shakapacker-webpack` pins `~6.5.1`. Apps still on `webpack-assets-manifest@5.x` must upgrade to v6 when adopting `shakapacker-webpack` — the v6 release fixed an ENOENT crash on clean builds with `merge: true` and dropped a Node 14 install path; see [the v5→v6 release notes](https://github.com/webdeveric/webpack-assets-manifest/releases) for details.
