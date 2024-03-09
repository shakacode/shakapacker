* For the changelog of versions prior to v6, see the [5.x stable branch of rails/webpacker](https://github.com/rails/webpacker/tree/5-x-stable).
* Please see the [v7 Upgrade Guide](./docs/v7_upgrade.md) for upgrading to new spelling in version 7.
* Please see the [v6 Upgrade Guide](./docs/v6_upgrade.md) to go from versions prior to v6.
* [ShakaCode](https://www.shakacode.com) offers support for upgrading from Webpacker or using Shakapacker. If interested, contact Justin Gordon, [justin@shakacode.com](mailto:justin@shakacode.com).

_next_ branch is for v8 changes

## Versions
## [Unreleased]
Changes since the last non-beta release.

### Breaking changes
- Remove `relative_url_root` [PR 413](https://github.com/shakacode/shakapacker/pull/413) by [G-Rath](https://github.com/g-rath).

- Removes deprecated support of `Webpacker` spelling, config variables and constants. [PR 429](https://github.com/shakacode/shakapacker/pull/429) by [tomdracz](https://github.com/tomdracz).

  The usage of those has been deprecated in Shakapacker v7 and now fully removed in v8. See the [v7 Upgrade Guide](./docs/v7_upgrade.md) for more information if you are still yet to address this deprecation.

- Remove `globalMutableWebpackConfig` global [PR 439](https://github.com/shakacode/shakapacker/pull/439) by [G-Rath](https://github.com/g-rath).

  Use `generateWebpackConfig` instead.

- Remove `yarn_install` rake task, and stop installing js packages automatically as part of `assets:precompile` [PR 412](https://github.com/shakacode/shakapacker/pull/412) by [G-Rath](https://github.com/g-rath).

- Remove `check_yarn` rake task [PR 443](https://github.com/shakacode/shakapacker/pull/443) by [G-Rath](https://github.com/g-rath).

- Remove `https` option for `webpack-dev-server` [PR 414](https://github.com/shakacode/shakapacker/pull/414) by [G-Rath](https://github.com/g-rath).

- Remove `verify_file_existance` method [PR 446](https://github.com/shakacode/shakapacker/pull/446) by [G-Rath](https://github.com/g-rath).

- Drop support for Ruby 2.6 [PR 415](https://github.com/shakacode/shakapacker/pull/415) by [G-Rath](https://github.com/g-rath).

- Drop support for Node v12 [PR 431](https://github.com/shakacode/shakapacker/pull/431) by [G-Rath](https://github.com/g-rath).

- Enable `ensure_consistent_versioning` by default [PR 447](https://github.com/shakacode/shakapacker/pull/447) by [G-Rath](https://github.com/g-rath).

### Added
- Emit warnings instead of errors when compilation is success but stderr is not empty. [PR 416](https://github.com/shakacode/shakapacker/pull/416) by [n-rodriguez](https://github.com/n-rodriguez).
- Allow `webpack-dev-server` v5. [PR 418](https://github.com/shakacode/shakapacker/pull/418) by [G-Rath](https://github.com/g-rath)

## [v7.2.2] - January 19, 2024

### Added
- Allow `compression-webpack-plugin` v11. [PR 406](https://github.com/shakacode/shakapacker/pull/406) by [tagliala](https://github.com/tagliala).

## [v7.2.1] - December 30, 2023

### Fixed
- Show deprecation message for `relative_url_root` only if it is set. [PR 400](https://github.com/shakacode/shakapacker/pull/400) by [ahangarha](https://github.com/ahangarha).

## [v7.2.0] - December 28, 2023

### Added
- Experimental support for other JS package managers using `package_json` gem [PR 349](https://github.com/shakacode/shakapacker/pull/349) by [G-Rath](https://github.com/g-rath).
- Support `hmr: only` configuration [PR 378](https://github.com/shakacode/shakapacker/pull/378) by [SimenB](https://github.com/SimenB).
- Use `config/shakapacker.yml` as the secondary source for `asset_host` and `relative_url_root` configurations [PR 376](https://github.com/shakacode/shakapacker/pull/376) by [ahangarha](https://github.com/ahangarha).

### Fixed
- Recommend `server` option instead of the deprecated `https` option when `--https` is provided [PR 380](https://github.com/shakacode/shakapacker/pull/380) by [G-Rath](https://github.com/g-rath)
- Recompile assets on asset host change [PR 364](https://github.com/shakacode/shakapacker/pull/364) by [ahangarha](https://github.com/ahangarha).
- Add deprecation warning for `https` option in `shakapacker.yml` (use `server: 'https'` instead) [PR 382](https://github.com/shakacode/shakapacker/pull/382) by [G-Rath](https://github.com/g-rath).
- Disable Hot Module Replacement in `webpack-dev-server` when `hmr: false` [PR 392](https://github.com/shakacode/shakapacker/pull/392) by [thedanbob](https://github.com/thedanbob).

### Deprecated
- The usage of `relative_url_root` is deprecated in Shakapacker and will be removed in v8. [PR 376](https://github.com/shakacode/shakapacker/pull/376) by [ahangarha](https://github.com/ahangarha).

## [v7.1.0] - September 30, 2023

### Added
- Support passing custom webpack config directly to `generateWebpackConfig` for merging [PR 343](https://github.com/shakacode/shakapacker/pull/343) by [G-Rath](https://github.com/g-rath).

### Fixed
- Use `NODE_OPTIONS` to enable Node-specific debugging flags [PR 350](https://github.com/shakacode/shakapacker/pull/350).
- Add the boilerplate `application.js` into `packs/` [PR 363](https://github.com/shakacode/shakapacker/pull/363).

## [v7.0.3] - July 7, 2023
### Fixed
- Fixed commands execution for projects with space in the absolute path [PR 322](https://github.com/shakacode/shakapacker/pull/322) by [kukicola](https://github.com/kukicola).

## [v7.0.2] - July 3, 2023
### Fixed
- Fixed creation of assets:precompile if it is missing [PR 325](https://github.com/shakacode/shakapacker/pull/325) by [ahangarha](https://github.com/ahangarha).

## [v7.0.1] - June 27, 2023
### Fixed
- Fixed the condition for showing warning for setting `useContentHash` to `false` in the production environment. [PR 320](https://github.com/shakacode/shakapacker/pull/320) by [ahangarha](https://github.com/ahangarha).

## [v7.0.0] - June 23, 2023
### Breaking changes
- Removes defaults passed to `@babel/preset-typescript`. [PR 273](https://github.com/shakacode/shakapacker/pull/273) by [tomdracz](https://github.com/tomdracz).

  `@babel/preset-typescript` has been initialised in default configuration with `{ allExtensions: true, isTSX: true }` - meaning every file in the codebase was treated as TSX leading to potential issues. This has been removed and returns to sensible default of the preset which is to figure out the file type from the extensions. This change might affect generated output however so it is marked as breaking.

- Export immutable webpackConfig function. [PR 293](https://github.com/shakacode/shakapacker/pull/293) by [tomdracz](https://github.com/tomdracz).

  The `webpackConfig` property in the `shakapacker` module has been updated to be a function instead of a global mutable webpack configuration. This function now returns an immutable webpack configuration object, which ensures that any modifications made to it will not affect any other usage of the webpack configuration. If a project still requires the old mutable object, it can be accessed by replacing `webpackConfig` with `globalMutableWebpackConfig`. Check [v7-upgrade](https://github.com/shakacode/shakapacker/blob/main/docs/v7_upgrade.md) documentation for more detail.

### Added
- Set CSS modules mode depending on file type. [PR 261](https://github.com/shakacode/shakapacker/pull/261) by [talyuk](https://github.com/talyuk).
- All standard webpack entries with the camelCase format are now supported in `shakapacker.yml` in snake_case format. [PR276](https://github.com/shakacode/shakapacker/pull/276) by [ahangarha](https://github.com/ahangarha).
- The `shakapacker:install` rake task now has an option to force overriding files using `FORCE=true` environment variable [PR311](https://github.com/shakacode/shakapacker/pull/311) by [ahangarha](https://github.com/ahangarha).
- Allow configuration of use of contentHash for specific environment [PR 234](https://github.com/shakacode/shakapacker/pull/234) by [justin808](https://github/justin808).

### Changed
- Rename Webpacker to Shakapacker in the entire project including config files, binstubs, environment variables, etc. with a high degree of backward compatibility.

  This change might be breaking for certain setups and edge cases. More information: [v7 Upgrade Guide](./docs/v7_upgrade.md) [PR157](https://github.com/shakacode/shakapacker/pull/157) by [ahangarha](https://github.com/ahangarha)

- Set `source_entry_path` to `packs` and `nested_entries` to `true` in`shakapacker.yml` [PR 284](https://github.com/shakacode/shakapacker/pull/284) by [ahangarha](https://github.com/ahangarha).
- Dev server configuration is modified to follow [webpack recommended configurations](https://webpack.js.org/configuration/dev-server/) for dev server. [PR276](https://github.com/shakacode/shakapacker/pull/276) by [ahangarha](https://github.com/ahangarha):
  - Deprecated `https` entry is removed from the default configuration file, allowing to set `server` or `https` as per the project requirements. For more detail, check webpack documentation. The `https` entry can be effective only if there is no `server` entry in the config file.
  - `allowed_hosts` is now set to `auto` instead of `all` by default.

- Remove the arbitrary stripping of the top-level directory when generating static file paths. [PR 283](https://github.com/shakacode/shakapacker/pull/283) by [tomdracz](https://github.com/tomdracz).

  Prior to this change, top level directory of static assets like images and fonts was stripped. This meant that file in `app/javascript/images/image.png` would be output to `static/image.png` directory and could be referenced through helpers as `image_pack_tag("image.jpg")` or `image_pack_tag("static/image.jpg")`.

  Going forward, the top level directory of static files will be retained so this will necessitate the update of file name references in asset helpers. In the example above, the file sourced from `app/javascript/images/image.png` will be now output to `static/images/image.png` and needs to be referenced as `image_pack_tag("images/image.jpg")` or `image_pack_tag("static/images/image.jpg")`.

### Fixed
- Move compilation lock file into the working directory. [PR 272](https://github.com/shakacode/shakapacker/pull/272) by [tomdracz](https://github.com/tomdracz).
- Process `source_entry_path` with values starting with `/` as a relative path to `source_path` [PR 284](https://github.com/shakacode/shakapacker/pull/284) by [ahangarha](https://github.com/ahangarha).
- Removes defaults passed to `@babel/preset-typescript` to make it possible to have projects with mix of JS and TS code [PR 273](https://github.com/shakacode/shakapacker/pull/273) by [tomdracz](https://github.com/tomdracz).

  `@babel/preset-typescript` has been initialised in default configuration with `{ allExtensions: true, isTSX: true }` - meaning every file in the codebase was treated as TSX leading to potential issues. This has been removed and returns to sensible default of the preset which is to figure out the file type from the extensions. This change might affect generated output however so it is marked as breaking.

- Fixed RC version detection during installation. [PR312](https://github.com/shakacode/shakapacker/pull/312) by [ahangarha](https://github.com/ahangarha)
- Fix addition of webpack-dev-server to devDependencies during installation. [PR310](https://github.com/shakacode/shakapacker/pull/310) by [ahangarha](https://github.com/ahangarha)
### Removed
- Remove redundant enhancement for precompile task to run `yarn install` [PR 270](https://github.com/shakacode/shakapacker/pull/270) by [ahangarha](https://github.com/ahangarha).
- Remove deprecated `check_yarn_integrity` from `Shakapacker::Configuration` [PR SP288](https://github.com/shakacode/shakapacker/pull/288) by [ahangarha](https://github.com/ahangarha).

## [v6.6.0] - March 7, 2023
### Improved
- Allow configuration of webpacker.yml through env variable. [PR 254](https://github.com/shakacode/shakapacker/pull/254) by [alecslupu](https://github.com/alecslupu).

## [v6.5.6] - February 11, 2023
### Fixed
- Fixed failing to update `bin/setup` file due to different formats of the file in different versions of Rails. [PR 229](https://github.com/shakacode/shakapacker/pull/229) by [ahangarha](https://github.com/ahangarha).

- Upgrade several JS dependencies to fix security issues. [PR 243](https://github.com/shakacode/shakapacker/pull/243) by [ahangarha](https://github.com/ahangarha).

- Added `prepend_javascript_pack_tag` to helpers. Allows to move an entry to the top of queue. Handy when calling from the layout to make sure an entry goes before the view and partial `append_javascript_pack_tag` entries. [PR 235](https://github.com/shakacode/shakapacker/pull/235) by [paypro-leon](https://github.com/paypro-leon).

- Fixed [issue](https://github.com/shakacode/shakapacker/issues/208) to support directories under `node_modules/*` in the `additional_paths` property of `webpacker.yml` [PR 240](https://github.com/shakacode/shakapacker/pull/240) by [vaukalak](https://github.com/vaukalak).
- Remove duplicate yarn installs. [PR 238](https://github.com/shakacode/shakapacker/pull/238) by [justin808](https://github/justin808).
- Remove unneeded code related to CSP config for generator. [PR 223](https://github.com/shakacode/shakapacker/pull/223) by [ahangarha](https://github/ahangarha).

## [v6.5.5] - December 28, 2022

### Improved
- Describe keys different from `webpack-dev-server` in generated `webpacker.yml`. [PR 194](https://github.com/shakacode/shakapacker/pull/194) by [alexeyr](https://github.com/alexeyr).
- Allow webpack-cli v5 [PR 216](https://github.com/shakacode/shakapacker/pull/216) by [tagliala](https://github.com/tagliala).
- Allow babel-loader v9 [PR 215](https://github.com/shakacode/shakapacker/pull/215) by [tagliala](https://github.com/tagliala).

## [v6.5.4] - November 4, 2022
### Fixed
- Fixed regression caused by 6.5.3. PR #192 introduce extra split() call. [PR 202](https://github.com/shakacode/shakapacker/pull/202) by [Eric-Guo](https://github.com/Eric-Guo).

## [v6.5.3] - November 1, 2022

### Improved
- Set RAILS_ENV and BUNDLE_GEMFILE env values before requiring `bundler/setup`, `webpacker`, and `webpacker/webpack_runner`. [PR 190](https://github.com/shakacode/shakapacker/pull/190) by [betmenslido](https://github.com/betmenslido).
- The `mini-css-extract-plugin` may cause various warnings indicating CSS order conflicts when using a [File-System-based automated bundle generation feature](https://www.shakacode.com/react-on-rails/docs/guides/file-system-based-automated-bundle-generation/).
CSS order warnings can be disabled in projects where CSS ordering has been mitigated by consistent use of scoping or naming conventions. Added `css_extract_ignore_order_warnings` flag to webpacker configuration to disable the order warnings by [pulkitkkr](https://github.com/shakacode/shakapacker/pull/185) in [PR 192](https://github.com/shakacode/shakapacker/pull/192).

## [v6.5.2] - September 8, 2022

### Upgrade
Remove the setting of the NODE_ENV in your `bin/webpacker` and `bin/webpacker-dev-server` files per [PR 185](https://github.com/shakacode/shakapacker/pull/185).

### Fixed
- Changed NODE_ENV defaults to the following and moved from binstubs to the runner. [PR 185](https://github.com/shakacode/shakapacker/pull/185) by [mage1711](https://github.com/mage1711).

```
ENV["NODE_ENV"] ||= (ENV["RAILS_ENV"] == "production") ? "production" : "development"
```

## [v6.5.1] - August 15, 2022

### Improved
- Resolve exact npm package version from lockfiles for constraint checking. [PR 170](https://github.com/shakacode/shakapacker/pull/170) by [G-Rath](https://github.com/G-Rath).

### Fixed
- `append_javascript_pack_tag` and `append_stylesheet_pack_tag` helpers return `nil` to prevent rendering the queue into view when using `<%= … %>` ERB syntax. [PR 167](https://github.com/shakacode/shakapacker/pull/167) by [ur5us](https://github.com/ur5us). While `<%=` should not be used, it's OK to return nil in case it's misused.
- Fixed non-runnable test due to wrong code nesting. [PR 173](https://github.com/shakacode/shakapacker/pull/173) by [ur5us](https://github.com/ur5us).
- Fixed default configurations not working for custom Rails environments [PR 168](https://github.com/shakacode/shakapacker/pull/168) by [ur5us](https://github.com/ur5us).
- Added accessor method for `nested_entries` configuration. [PR 176](https://github.com/shakacode/shakapacker/pull/176) by [pulkitkkr](https://github.com/pulkitkkr).

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
- Add `dev_server.inline_css: bool` config option to allow for opting out of style-loader and into mini-css-extract-plugin for CSS HMR in development. [PR 69](https://github.com/shakacode/shakapacker/pull/69) by [cheald](https://github.com/cheald).

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

[Unreleased]: https://github.com/shakacode/shakapacker/compare/v7.2.2...main
[v7.2.2]: https://github.com/shakacode/shakapacker/compare/v7.2.1...v7.2.2
[v7.2.1]: https://github.com/shakacode/shakapacker/compare/v7.2.0...v7.2.1
[v7.2.0]: https://github.com/shakacode/shakapacker/compare/v7.1.0...v7.2.0
[v7.1.0]: https://github.com/shakacode/shakapacker/compare/v7.0.3...v7.1.0
[v7.0.3]: https://github.com/shakacode/shakapacker/compare/v7.0.2...v7.0.3
[v7.0.2]: https://github.com/shakacode/shakapacker/compare/v7.0.1...v7.0.2
[v7.0.1]: https://github.com/shakacode/shakapacker/compare/v7.0.0...v7.0.1
[v7.0.0]: https://github.com/shakacode/shakapacker/compare/v6.6.0...v7.0.0
[v6.6.0]: https://github.com/shakacode/shakapacker/compare/v6.5.6...v6.6.0
[v6.5.6]: https://github.com/shakacode/shakapacker/compare/v6.5.5...v6.5.6
[v6.5.5]: https://github.com/shakacode/shakapacker/compare/v6.5.4...v6.5.5
[v6.5.4]: https://github.com/shakacode/shakapacker/compare/v6.5.3...v6.5.4
[v6.5.3]: https://github.com/shakacode/shakapacker/compare/v6.5.2...v6.5.3
[v6.5.2]: https://github.com/shakacode/shakapacker/compare/v6.5.1...v6.5.2
[v6.5.1]: https://github.com/shakacode/shakapacker/compare/v6.5.0...v6.5.1
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
