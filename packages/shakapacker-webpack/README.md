# shakapacker-webpack

`shakapacker-webpack` is the supplemental package for Shakapacker's managed webpack build path. It pairs `shakapacker` with the exact webpack, loader, and plugin versions that Shakapacker currently supports for the standard webpack setup.

## Install

`shakapacker-webpack` ships `shakapacker` and `terser-webpack-plugin` as direct dependencies and declares `webpack`, `webpack-cli`, and `webpack-assets-manifest` as **required peer dependencies**. On npm 7+, a single install pulls in the full managed build stack via auto-peer-install:

```sh
# npm 7+ — auto-installs required peers
npm install --save-dev shakapacker-webpack
```

pnpm and Yarn PnP keep dependency boundaries strict: packages imported by your app's config files must be listed directly in your app's `package.json`. The default generated webpack config imports `shakapacker`, and many customized configs import `webpack`, so keep those direct dependencies alongside the supplemental package:

```sh
# pnpm
pnpm add --save-dev shakapacker-webpack shakapacker webpack webpack-cli webpack-assets-manifest terser-webpack-plugin

# yarn
yarn add --dev shakapacker-webpack shakapacker webpack webpack-cli webpack-assets-manifest terser-webpack-plugin
```

`terser-webpack-plugin` is in the list because core `shakapacker`'s default minimizer calls `require("terser-webpack-plugin")` from inside the core package. Under pnpm and Yarn PnP, that require only resolves if the host app declares it directly — `shakapacker-webpack`'s direct dependency on it doesn't reach across the strict package boundary. npm 7+'s flat `node_modules` hoists it automatically, so npm users don't need to list it.

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

Optional peers (transpilers, `webpack-dev-server`, `mini-css-extract-plugin`, CSS preprocessors, etc.) stay only if your app uses those features. Run `yarn install` (or the npm/pnpm equivalent) and the lockfile collapses to the managed stack. npm 7+ can auto-install the required peers; pnpm and Yarn users should keep `shakapacker`, `webpack`, `webpack-cli`, `webpack-assets-manifest`, and `terser-webpack-plugin` as explicit `devDependencies` unless their config imports the wrapper package directly.

### Migrating from core's webpack peer set

Core `shakapacker` accepts both `webpack-assets-manifest` v5 and v6 (`^5.0.6 || ^6.0.0`). `shakapacker-webpack` requires `^6.0.0`. Apps still on `webpack-assets-manifest@5.x` must upgrade to v6 when adopting `shakapacker-webpack` — the v6 release fixed an ENOENT crash on clean builds with `merge: true` and dropped a Node 14 install path; see [the v5→v6 release notes](https://github.com/webdeveric/webpack-assets-manifest/releases) for details.
