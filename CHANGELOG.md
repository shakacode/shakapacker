* For the changelog of versions prior to v6, see the [5.x stable branch of rails/webpacker](https://github.com/rails/webpacker/tree/5-x-stable).
* Please see the [v6 Upgrade Guide](./docs/v6_upgrade.md) to go from versions prior to v6.
* [ShakaCode](https://www.shakacode.com) offers support for upgrading from webpacker or using Shakapacker. If interested, contact Justin Gordon, [justin@shakacode.com](mailto:justin@shakacode.com).

## Versions
## [Unreleased]
Changes since last non-beta release.

_Please add entries here for your pull requests that are not yet released._

## [v6.5.0] - July 4, 2022
### Added
- `append_stylesheet_pack_tag` helper. It helps in configuring stylesheet pack names from the view for a route or partials. It is also required for filesystem-based automated Component Registry API on React on Rails gem. [PR 144](https://github.com/shakacode/shakapacker/pull/144) by [pulkitkkr](https://github.com/pulkitkkr).

### Improved
- Make sure at most one compilation runs at a time [PR 139](https://github.com/shakacode/shakapacker/pull/139) by [artemave](https://github.com/artemave)

## [v6.4.1] - June 5, 2022
### Fixed
- Restores automatic installation of yarn packages removed in [#131](https://github.com/shakacode/shakapacker/pull/131), with added deprecation notice. [PR 140](https://github.com/shakacode/shakapacker/pull/140) by [tomdracz](https://github.com/tomdracz).

  This will be again removed in Shakapacker v7 so you need to ensure you are installing yarn packages explicitly before the asset compilation, rather than relying on this behaviour through `asset:precompile` task (e.g. Capistrano deployment).

- Disable Spring being used by `rails-erb-loader`. [PR 141](https://github.com/shakacode/shakapacker/pull/141) by [tomdracz](https://github.com/tomdracz).

## [v6.4.0] - June 2, 2022
### Fixed
- Fixed [Issue 123: Rails 7.0.3 - Webpacker configuration file not found when running rails webpacker:install (shakapacker v6.3)](https://github.com/shakacode/shakapacker/issues/123) in [PR 136: Don't enhance precompile if no config #136](https://github.com/shakacode/shakapacker/pull/136) by [justin808](https://github.com/justin808).

### Added
- Configuration boolean option `nested_entries` to use nested entries. This was the default prior to v6.0. Because entries maybe generated, it's useful to allow a `generated` subdirectory. [PR 121](https://github.com/shakacode/shakapacker/pull/121) by [justin808](https://github.com/justin808). 

### Improved
- Allow v10 of `compression-webpack-plugin` as a peer dependency. [PR 117](https://github.com/shakacode/shakapacker/pull/117) by [aried3r](https://github.com/aried3r).

- [Remove assets:precompile task enhancement #131](https://github.com/shakacode/shakapacker/pull/131) by [James Herdman](https://github.com/jherdman): Removed the `yarn:install` Rake task, and no longer enhance `assets:precompile` with said task. These tasks were used to ensure required NPM packages were installed before asset precompilation. Going forward you will need to ensure these packages are already installed yourself. Should you wish to restore this behaviour you'll need to [reimplement the task](https://github.com/shakacode/shakapacker/blob/bee661422f2c902aa8ac9cf8fa1f7ccb8142c914/lib/tasks/yarn.rake) in your own application.

## [v6.3.0] - May 19, 2022

### Improved
- Add ability to configure usage of either last modified timestamp and digest strategies when checking asset freshness. [PR 112](https://github.com/shakacode/shakapacker/pull/112) by [tomdracz](https://github.com/tomdracz). 

### Fixed
- On Windows CSS urls no longer contain backslashes resulting in 404 errors. [PR 115](https://github.com/shakacode/shakapacker/pull/115) by [daniel-rikowski](https://github.com/daniel-rikowski).

## [v6.3.0-rc.1] - April 24, 2022

Note: [Rubygem is 6.3.0.pre.rc.1](https://rubygems.org/gems/shakapacker/versions/6.3.0.pre.rc.1) and [NPM is 6.3.0-rc.1](https://www.npmjs.com/package/shakapacker/v/6.3.0-rc.1).

### Changed
- Remove Loose mode from the default @babel-preset/env configuration. [PR 107](https://github.com/shakacode/shakapacker/pull/107) by [Jeremy Liberman](https://github.com/MrLeebo).

  Loose mode compiles the bundle down to be compatible with ES5, but saves space by skipping over behaviors that are considered edge cases. Loose mode can affect how your code runs in a variety of ways, but in newer versions of Babel it's better to use [Compiler Assumptions](https://babeljs.io/docs/en/assumptions) to have finer-grained control over which edge cases you're choosing to ignore. 

  This change may increase the file size of your bundles, and may change some behavior in your app if your code touches upon one of the edge cases where Loose mode differs from native JavaScript. There are notes in the linked PR about how to turn Loose mode back on if you need to, but consider migrating to Compiler Assumptions when you can. If you have already customized your babel config, this change probably won't affect you.
  
### Added
- Adds `webpacker_precompile` setting to `webpacker.yml` to allow controlling precompile behaviour, similar to existing `ENV["WEBPACKER_PRECOMPILE"]` variable. [PR 102](https://github.com/shakacode/shakapacker/pull/102) by [Judahmeek](https://github.com/Judahmeek).
- Adds `append_javascript_pack_tag` helper. Allows for easier usage and coordination of multiple javascript packs. [PR 94](https://github.com/shakacode/shakapacker/pull/94) by [tomdracz](https://github.com/tomdracz).

### Improved
- Use last modified timestamps rather than file digest to determine compiler freshness. [PR 97](https://github.com/shakacode/shakapacker/pull/97) by [tomdracz](https://github.com/tomdracz).

  Rather than calculating SHA digest of all the files in the paths watched by the compiler, we are now comparing the modified time of the `manifest.json` file versus the latest modified timestamp of files and directories in watched paths. Unlike calculating digest, which only looked at the files, the new calculation also considers directory timestamps, including the parent ones (i.e. `config.source_path` folder timestamp will be checked together will timestamps of all files and directories inside of it).

  This change should result in improved compiler checks performance but might be breaking for certain setups and edge cases. If you encounter any issues, please report them at https://github.com/shakacode/shakapacker/issues.

- Bump dependency versions in package.json to address security vulnerabilities. [PR 109](https://github.com/shakacode/shakapacker/pull/109) by [tomdracz](https://github.com/tomdracz).
- Add `webpack-dev-server` as `peerDependency` to make its usage clear. [PR 109](https://github.com/shakacode/shakapacker/pull/109) by [tomdracz](https://github.com/tomdracz).

## [v6.2.1] - April 15, 2022
### Fixed
- Put back config.public_manifest_path, removed in 6.2.0 in PR 78. [PR 104](https://github.com/shakacode/shakapacker/pull/104) by [justin808](https://github.com/justin808).

## [v6.2.0] - March 22, 2022

### Added
- Make manifest_path configurable, to keep manifest.json private if desired. [PR 78](https://github.com/shakacode/shakapacker/pull/78) by [jdelStrother](https://github.com/jdelStrother).
- Rewrite webpack module rules as regular expressions. Allows for easy iteration during config customization. [PR 60](https://github.com/shakacode/shakapacker/pull/60) by [blnoonan](https://github.com/blnoonan).
- Initialization check to ensure shakapacker gem and NPM package version are consistent. Opt-in behaviour enabled by setting `ensure_consistent_versioning` configuration variable. [PR 51](https://github.com/shakacode/shakapacker/pull/51) by [tomdracz](https://github.com/tomdracz).
- Add `dev_server.inline_css: bool` config option to allow for opting out of style-loader and into mini-extract-css-plugin for CSS HMR in development. [PR 69](https://github.com/shakacode/shakapacker/pull/69) by [cheald](https://github.com/cheald).

### Improved
- Increase default connect timeout for dev server connections, establishing connections more reliably for busy machines. [PR 74](https://github.com/shakacode/shakapacker/pull/74) by [stevecrozz](https://github.com/stevecrozz).
- Allow multiple invocations of stylesheet_pack_tag (eg for a regular stylesheet & a print stylesheet). [PR 82](https://github.com/shakacode/shakapacker/pull/82) by [jdelStrother](https://github.com/jdelStrother).
- Tweak swc config for parity with Babel. [PR 79](https://github.com/shakacode/shakapacker/pull/79) by [dleavitt](https://github.com/dleavitt).

## [v6.1.1] - February 6, 2022

### Added
- Support for esbuild-loader. [PR 53](https://github.com/shakacode/shakapacker/pull/53) by [tomdracz](https://github.com/tomdracz).

## [v6.1.0] - February 4, 2022
### Added
- Support for SWC loader. [PR 29](https://github.com/shakacode/shakapacker/pull/29) by [tomdracz](https://github.com/tomdracz).

### Fixed
- Static asset subdirectories are retained after compilation, matching Webpacker v5 behaviour. [PR 47](https://github.com/shakacode/shakapacker/pull/47) by [tomdracz](https://github.com/tomdracz). Fixes issues [rails/webpacker#2956](https://github.com/rails/webpacker/issues/2956) which broke in [rails/webpacker#2802](https://github.com/rails/webpacker/pull/2802).

## [v6.0.2] - January 25, 2022
### Improved
- Fix incorrect command name in warning. [PR 33](https://github.com/shakacode/shakapacker/pull/33) by [tricknotes](https://github.com/tricknotes).

## [v6.0.1] - January 24, 2022
### Improved
- PR #21 removed pnp-webpack-plugin as a dev dependency but did not remove it from the peer dependency list. [PR 30](https://github.com/shakacode/shakapacker/pull/30) by [t27duck](https://github.com/t27duck).

## [v6.0.0 changes from v6.0.0.rc.6] - January 22, 2022

### Improved
- Raise on multiple invocations of javascript_pack_tag and stylesheet_pack_tag helpers. [PR 19](https://github.com/shakacode/shakapacker/pull/19) by [tomdracz](https://github.com/tomdracz).
- Remove automatic addition of node_modules into rails asset load path. [PR 20](https://github.com/shakacode/shakapacker/pull/20) by [tomdracz](https://github.com/tomdracz).
- Remove pnp-webpack-plugin. [PR 21](https://github.com/shakacode/shakapacker/pull/21) by [tomdracz](https://github.com/tomdracz).


### Merged from rails/webpacker

- Make watched_files_digest thread safe. [rails/webpacker #3233](https://github.com/rails/webpacker/pull/3233)
- Use single webpack config webpack.config.js. [rails/webpacker #3240](https://github.com/rails/webpacker/pull/3240)
- Switch to peer dependencies. [rails/webpacker #3234](https://github.com/rails/webpacker/pull/3234)

### Upgrading from rails/webpacker 6.0.0.rc.6
- Single default configuration file of `config/webpack/webpack.config.js`. Previously, the config file was set
  to `config/webpack/#{NODE_ENV}.js`.
- Changed all package.json dependencies to peerDependencies, so upgrading requires adding the dependencies, per the [UPGRADE GUIDE](./docs/v6_upgrade.md).

## [v6.0.0.rc.6 changes from v5.4] - Forked January 16, 2022


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
- Deprecated configuration option `watched_paths`. Use `additional_paths` instead in `webpacker.yml`.

### Breaking changes
- Renamed `/bin/webpack` to `/bin/webpacker` and `/bin/webpack-dev-server` to `bin/webpacker-dev-server` to avoid confusion with underlying webpack executables.
- Removed integration installers
- Splitchunks enabled by default
- CSS extraction enabled by default, except when devServer is configured and running

## v5.4.3 and prior changes from rails/webpacker
See [CHANGELOG.md in rails/webpacker (up to v5.4.3)](https://github.com/rails/webpacker/blob/master/CHANGELOG.md) 

[Unreleased]: https://github.com/shakacode/shakapacker/compare/v6.5.0...master
[v6.5.0]: https://github.com/shakacode/shakapacker/compare/v6.4.1...v6.5.0
[v6.4.1]: https://github.com/shakacode/shakapacker/compare/v6.4.0...v6.4.1
[v6.4.0]: https://github.com/shakacode/shakapacker/compare/v6.3.0...v6.4.0
[v6.3.0]: https://github.com/shakacode/shakapacker/compare/v6.2.1...v6.3.0
[v6.2.1]: https://github.com/shakacode/shakapacker/compare/v6.2.0...v6.2.1
[v6.2.0]: https://github.com/shakacode/shakapacker/compare/v6.1.1...v6.2.0
[v6.1.1]: https://github.com/shakacode/shakapacker/compare/v6.1.0...v6.1.1
[v6.1.0]: https://github.com/shakacode/shakapacker/compare/v6.0.2...v6.1.0
[v6.0.2]: https://github.com/shakacode/shakapacker/compare/v6.0.1...v6.0.2
[v6.0.1]: https://github.com/shakacode/shakapacker/compare/v6.0.0...v6.0.1
[v6.0.0 changes from v6.0.0.rc.6]: https://github.com/shakacode/shakapacker/compare/aba79635e6ff6562ec04d3c446d57ef19a5fef7d...v6.0.0
[v6.0.0.rc.6 changes from v5.4]: https://github.com/rails/webpacker/compare/v5.4.3...aba79635e6ff6562ec04d3c446d57ef19a5fef7d
