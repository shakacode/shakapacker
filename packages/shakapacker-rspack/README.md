# shakapacker-rspack

`shakapacker-rspack` is the supplemental package for Shakapacker's managed Rspack build path. It pairs `shakapacker` with the exact Rspack packages and related loader versions that Shakapacker currently supports.

## Install

`shakapacker-rspack` ships `shakapacker` as a direct dependency and declares `@rspack/core`, `@rspack/cli`, and `rspack-manifest-plugin` as **required peer dependencies**. On npm 7+, a single install pulls in the full managed build stack via auto-peer-install:

```sh
# npm 7+ — auto-installs required peers
npm install --save-dev shakapacker-rspack
```

pnpm and Yarn PnP keep dependency boundaries strict: packages imported by your app's config files must be listed directly in your app's `package.json`. The default generated rspack config imports `shakapacker/rspack`, so keep `shakapacker` and the required peers as direct dependencies alongside the supplemental package:

```sh
# pnpm
pnpm add --save-dev shakapacker-rspack shakapacker @rspack/core @rspack/cli rspack-manifest-plugin

# yarn
yarn add --dev shakapacker-rspack shakapacker @rspack/core @rspack/cli rspack-manifest-plugin
```

(The Rails `shakapacker:install` task writes all required deps into your `package.json` regardless of package manager.)

`@rspack/cli` is required because `bin/shakapacker` (Shakapacker's standard build/dev-server entrypoint) shells out to the `rspack` CLI binary rather than driving Rspack via the JS API.

Rspack includes SWC transpilation, so no separate JavaScript transpiler package is required. Install optional peers such as `@rspack/plugin-react-refresh`, `css-loader`, `sass`, and `sass-loader` only when your app uses those features.

### Simplifying an existing rspack install

If your app already runs Shakapacker on Rspack, you can drop the managed-build deps from your `package.json` — they come along with `shakapacker-rspack`:

**Before (v10.0):**

```json
{
  "devDependencies": {
    "shakapacker": "^10.0.0",
    "@rspack/core": "^2.0.0",
    "@rspack/cli": "^2.0.0",
    "rspack-manifest-plugin": "^5.0.0"
  }
}
```

**After (v10.1+ with `shakapacker-rspack`):**

```json
{
  "devDependencies": {
    "shakapacker-rspack": "~10.1.0"
  }
}
```

Optional peers (`@rspack/plugin-react-refresh`, `css-loader`, `sass`, `sass-loader`) stay only if your app uses those features. Run `yarn install` (or the npm/pnpm equivalent) and the lockfile collapses to the managed stack. npm 7+ can auto-install the required peers; pnpm and Yarn users should keep `shakapacker`, `@rspack/core`, `@rspack/cli`, and `rspack-manifest-plugin` as explicit `devDependencies` unless their config imports the wrapper package directly.
