# shakapacker-rspack

`shakapacker-rspack` is the supplemental package for Shakapacker's managed Rspack build path. It pairs `shakapacker` with the exact Rspack packages and related loader versions that Shakapacker currently supports.

## Install

`shakapacker-rspack` ships `shakapacker`, `@rspack/core`, `@rspack/cli`, and `rspack-manifest-plugin` as direct dependencies, so a single install pulls in the full managed build stack:

```sh
# yarn
yarn add --dev shakapacker-rspack

# npm
npm install --save-dev shakapacker-rspack

# pnpm
pnpm add --save-dev shakapacker-rspack
```

`@rspack/cli` is bundled because `bin/shakapacker` (Shakapacker's standard build/dev-server entrypoint) shells out to the `rspack` CLI binary rather than driving Rspack via the JS API.

Rspack includes SWC transpilation, so no separate JavaScript transpiler package is required. Install optional peers such as `@rspack/plugin-react-refresh@~2.0.1`, `css-loader@~7.1.4`, `sass@~1.99.0`, and `sass-loader@~16.0.7` only when your app uses those features.
