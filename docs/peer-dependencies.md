# Shakapacker's Peer Dependencies

Current supported ranges live in [`package.json`](../package.json) and
[`lib/install/package.json`](../lib/install/package.json).

Shakapacker declares these packages as optional peer dependencies via
`peerDependenciesMeta`. `shakapacker:install` adds the relevant subset for your
chosen bundler/transpiler stack, while the ranges below document what current
releases support.

## Common Packages

```text
"compression-webpack-plugin": "^9.0.0 || ^10.0.0 || ^11.0.0 || ^12.0.0"
"css-loader": "^6.8.1 || ^7.0.0"
"mini-css-extract-plugin": "^2.0.0"
"sass": "^1.50.0"
"sass-loader": "^13.0.0 || ^14.0.0 || ^15.0.0 || ^16.0.0"
"terser-webpack-plugin": "^5.3.1"
"webpack-assets-manifest": "^5.0.6 || ^6.0.0"
"webpack-cli": "^4.9.2 || ^5.0.0 || ^6.0.0 || ^7.0.0"
"webpack-dev-server": "^5.2.2"
"webpack-subresource-integrity": "^5.1.0"
```

## Webpack

```text
"webpack": "^5.101.0"
"webpack-merge": "^5.8.0 || ^6.0.0"
```

## Rspack

```text
"@rspack/cli": "^1.0.0 || ^2.0.0-0"
"@rspack/core": "^1.0.0 || ^2.0.0-0"
"@rspack/plugin-react-refresh": "^1.0.0"
"rspack-manifest-plugin": "^5.0.0"
```

## Babel

Installed when you explicitly use `javascript_transpiler: "babel"`:

```text
"@babel/core": "^7.17.9"
"@babel/plugin-transform-runtime": "^7.17.0"
"@babel/preset-env": "^7.16.11"
"@babel/runtime": "^7.17.9"
"babel-loader": "^8.2.4 || ^9.0.0 || ^10.0.0"
```

## SWC

Default for webpack installs, and used natively by Rspack:

```text
"@swc/core": "^1.3.0"
"swc-loader": "^0.1.15 || ^0.2.0"
```

## esbuild

```text
"esbuild": "^0.14.0 || ^0.15.0 || ^0.16.0 || ^0.17.0 || ^0.18.0 || ^0.19.0 || ^0.20.0 || ^0.21.0 || ^0.22.0 || ^0.23.0 || ^0.24.0 || ^0.25.0 || ^0.26.0 || ^0.27.0"
"esbuild-loader": "^2.0.0 || ^3.0.0 || ^4.0.0"
```

## TypeScript Authoring Helpers

These are optional peers used for the published type definitions and typed config authoring:

```text
"@types/babel__core": "^7.0.0"
"@types/webpack": "^5.0.0"
```
