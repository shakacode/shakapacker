# shakapacker-rspack

`shakapacker-rspack` is the supplemental package for Shakapacker's managed Rspack build path. It pairs `shakapacker` with the exact Rspack packages and related loader versions that Shakapacker currently supports.

## Install

```sh
npm install --save-dev shakapacker@^10.1.0 shakapacker-rspack@^10.1.0 @rspack/core@2.0.1 @rspack/cli@2.0.1 rspack-manifest-plugin@5.2.1
```

`@rspack/cli` is a required peer because `bin/shakapacker` (Shakapacker's standard build/dev-server entrypoint) shells out to the `rspack` CLI binary rather than driving Rspack via the JS API. Apps that exclusively drive Rspack programmatically can still install this package without `@rspack/cli`, but they will lose `bin/shakapacker` and `bin/shakapacker-dev-server`.

Rspack includes SWC transpilation, so no separate JavaScript transpiler package is required. Install optional peers such as `@rspack/plugin-react-refresh@2.0.1`, `css-loader@7.1.4`, `sass@1.99.0`, and `sass-loader@16.0.7` only when your app uses those features.
