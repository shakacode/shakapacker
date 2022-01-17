For versions prior to v6, see the [5.x stable branch of rails/webpacker](https://github.com/rails/webpacker/tree/5-x-stable).

## [[6.0.0]](https://github.com/rails/webpacker/compare/v5.4.3...master) - 2022

Latest is rc.9.

Please see [UPGRADE GUIDE](./docs/v6_upgrade.md) for more information.
- Single default configuration file of `config/webpack/webpack.config.js`. Previously, the config file was set
  to `config/webpack/#{NODE_ENV}.js`. 

- `node_modules` will no longer be babel transfomed compiled by default. This primarily fixes [rails issue #35501](https://github.com/rails/rails/issues/35501) as well as [numerous other webpacker issues](https://github.com/rails/webpacker/issues/2131#issuecomment-581618497). The disabled loader can still be required explicitly via:

  ```js
  const nodeModules = require('@rails/webpacker/rules/node_modules.js')
  environment.loaders.append('nodeModules', nodeModules)
  ```

- If you have added `environment.loaders.delete('nodeModules')` to your `environment.js`, this must be removed or you will receive an error (`Item nodeModules not found`).
- `extract_css` option was removed. Webpacker will generate a separate `application.css` file for the default `application` pack, as supported by multiple files per entry introduced in 5.0.0. [#2608](https://github.com/rails/webpacker/pull/2608). However, CSS will be inlined when the webpack-dev-server is used with `hmr: true`. JS package exports `inliningCss`. This is useful to enable HMR for React.
- Webpacker's wrapper to the `splitChunks()` API will now default `runtimeChunk: 'single'` which will help prevent potential issues when using multiple entry points per page [#2708](https://github.com/rails/webpacker/pull/2708).
- Changes `@babel/preset-env` modules option to `'auto'` per recommendation in the Babel docs [#2709](https://github.com/rails/webpacker/pull/2709)
- Adds experimental Yarn 2 support. Note you must manually set `nodeLinker: node-modules` in your `.yarnrc.yml`.
- Fixes dev server issues [#2898](https://github.com/rails/webpacker/pull/2898)
- Update static files path to from `media/` to `static/`.
- Changed all package.json dependencies to peerDependencies, so upgrading requires adding the dependencies, per the [UPGRADE GUIDE](./docs/v6_upgrade.md).
- Deprecated configuration option `watched_paths`. Use `additional_paths` instead in `webpacker.yml`.

### Breaking changes
- Renamed `/bin/webpack` to `/bin/webpacker` and `/bin/webpack-dev-server` to `bin/webpacker-dev-server` to avoid confusion with underlying webpack executables.
- Removed integration installers
- Splitchunks enabled by default
- CSS extraction enabled by default, except when devServer is configured and running
