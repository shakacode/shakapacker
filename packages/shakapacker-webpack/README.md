# shakapacker-webpack

`shakapacker-webpack` is the supplemental package for Shakapacker's managed webpack build path. It pairs `shakapacker` with the exact webpack, loader, and plugin versions that Shakapacker currently supports for the standard webpack setup.

## Install

`shakapacker-webpack` ships `shakapacker` and `terser-webpack-plugin` as direct dependencies and declares `webpack`, `webpack-cli`, and `webpack-assets-manifest` as **required peer dependencies**. On modern package managers, a single install pulls in the full managed build stack via auto-peer-install:

```sh
# npm 7+ — auto-installs required peers
npm install --save-dev shakapacker-webpack

# pnpm — auto-installs required peers
pnpm add --save-dev shakapacker-webpack

# yarn 2+ (Berry) — auto-installs required peers
yarn add --dev shakapacker-webpack
```

**Yarn classic 1.x does not auto-install peer dependencies.** Add the required peers explicitly:

```sh
yarn add --dev shakapacker-webpack webpack webpack-cli webpack-assets-manifest
```

(The Rails `shakapacker:install` task writes all required deps into your `package.json` regardless of package manager.)

**At least one JavaScript transpiler pair is required** — the runtime emits `SHAKAPACKER_NO_TRANSPILER` if none resolves. For the default SWC path, install `@swc/core` and `swc-loader`. Babel (`@babel/core` + `babel-loader`) and esbuild (`esbuild` + `esbuild-loader`) are also supported when set via `javascript_transpiler:` in `config/shakapacker.yml`. For dev-server/HMR usage, install `webpack-dev-server` (`^5.2.2`); webpack-dev-server 4.x remains part of the legacy core compatibility window, not the supplemental package's managed stack.

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

Optional peers (transpilers, `webpack-dev-server`, `mini-css-extract-plugin`, CSS preprocessors, etc.) stay only if your app uses those features. Run `yarn install` (or the npm/pnpm equivalent) and the lockfile collapses to the managed stack — on npm 7+, pnpm, and yarn 2+ the required peers (`webpack`, `webpack-cli`, `webpack-assets-manifest`) auto-install; yarn 1 users keep them as explicit `devDependencies`.

### Migrating from core's webpack peer set

Core `shakapacker` accepts both `webpack-assets-manifest` v5 and v6 (`^5.0.6 || ^6.0.0`). `shakapacker-webpack` requires `^6.0.0`. Apps still on `webpack-assets-manifest@5.x` must upgrade to v6 when adopting `shakapacker-webpack` — the v6 release fixed an ENOENT crash on clean builds with `merge: true` and dropped a Node 14 install path; see [the v5→v6 release notes](https://github.com/webdeveric/webpack-assets-manifest/releases) for details.
