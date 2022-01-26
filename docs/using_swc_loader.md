# Using SWC Loader

:warning: This feature is currently experimental. If you face any issues, please report at https://github.com/shakacode/shakapacker/issues

## About SWC

[SWC (Speedy Web compiler)](https://swc.rs/) is a Rust based compilation and bundler tool that can be used for Javascript and Typescript files. It claims to be 20x faster than Babel!

It supports all ECMAScript features and it's designed to be a drop-in replacement for Babel and it's plugins. Out of the box it supports TS, JSX syntax, React fast refresh and much more.

For comparison between SWC and Babel, see the docs at https://swc.rs/docs/migrating-from-babel

## Switching your Shakapacker project to SWC

In order to use SWC as your compiler today. You need to do two things:

1. Make sure you've installed `@swc/core` and `swc-loader` packages

```
yarn add -D @swc/core swc-loader
```

2. Add or change `webpacker_loader` value in your default `webpacker.yml` config to `swc`
The default configuration of babel is done by using `package.json` to use the file within the `shakapacker` package.

```json
default: &default
  source_path: app/javascript
  source_entry_path: /
  public_root_path: public
  public_output_path: packs
  cache_path: tmp/webpacker
  webpack_compile_output: true

  # Additional paths webpack should look up modules
  # ['app/assets', 'engine/foo/app/assets']
  additional_paths: []

  # Reload manifest.json on all requests so we reload latest compiled packs
  cache_manifest: false

  # Select loader to use, available options are 'babel' (default) or 'swc'
  webpack_loader: 'swc'
```

## Usage

### React
React is supported out of the box, provided you use `.jsx` or `.tsx` file extension. Shakapacker config will correctly recognise those and tell SWC to parse the JSX syntax correctly

Fast refresh is supported out of the box, provided you use it in development (`NODE_ENV=development`) and `env.WEBPACK_SERVE` is true (running `webpack-dev-server`)

### Typescript
Typescript is supported out of the box. Some features like decorators however might not be currently enabled

## Known limitations
- `browserslist` config at the moment is not being picked up automatically. [Related SWC issue](https://github.com/swc-project/swc/issues/3365)
- Using `.swcrc` config file is currently not supported. You might face some issues when `.swcrc` config is diverging from the SWC options we're passing in the Webpack rule
