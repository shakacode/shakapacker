# Upgrading from Shakapacker v7 to v8

The majority of the breaking changes in v8 were about dropping deprecated functions and features, along with switching to be agnostic about what package manager is used to manage JavaScript dependencies.

Support for Ruby 2.6 and Node v12 has also been dropped since they're very old at this point.

## The `packageManager` property in `package.json` is used to determine the package manager

The biggest functional change in v8, `shakapacker` is now able to work with any of the major JavaScript package managers thanks to the [`package_json`](https://github.com/shakacode/package_json) gem which uses the [`packageManager`](https://nodejs.org/api/packages.html#packagemanager) property in the `package.json`.

In alignment with the behaviour of Node and `corepack`, in the absence of the `packageManager` property `npm` will be used as the package manager so as part of upgrading you will want to ensure that is set to `yarn@<version>` if you want to continue using Yarn.

An error will be raised in the presences of a lockfile other than `package-lock.json` if this property is not set with the recommended value to use, but it important the property is set to ensure all tooling uses the right package manager.

The `check_yarn` rake task has also been renamed to `check_manager` to reflect this change.

Check out the [installation section](../README.md#installation) of the readme for more details.

## Usages of `webpacker` must now be `shakapacker`

The `webpacker` spelling was deprecated in v7 and has now been completely removed in v8 - this includes constants, environment variables, and rake tasks.

If you are still using references to `webpacker`, see the [v7 Upgrade Guide](../docs/v7_upgrade.md) for how to migrate.

## JavaScript dependencies are no longer installed automatically as part of `assets:precompile`

You will now need to ensure your dependencies are installed before compiling assets.

Some platforms like Heroku will install dependencies automatically but if you're using a tool like `capistrano` to deploy to servers you can enhance the `assets:precompile` command like so:

```ruby
namespace :assets do
  desc "Ensures that dependencies required to compile assets are installed"
  task install_dependencies: :environment do
    # npm v6+
    raise if File.exist?("package.json") && !(system "npm ci")

    # yarn v1.x (classic)
    raise if File.exist?("package.json") && !(system "yarn install --immutable")

    # yarn v2+ (berry)
    raise if File.exist?("package.json") && !(system "yarn install --frozen-lockfile")

    # bun v1+
    raise if File.exist?("package.json") && !(system "bun install --frozen-lockfile")

    # pnpm v6+
    raise if File.exist?("package.json") && !(system "pnpm install --frozen-lockfile")
  end
end

Rake::Task["assets:precompile"].enhance ["assets:install_dependencies"]
```

This allows more flexibility than what `shakapacker` could provide - for example, you might only want to do an immutable install if you're in CI. 

## `ensure_consistent_versioning` is now enabled by default

This has `shakapacker` check that the versions of the installed Ruby gem and JavaScript package are compatible; this should only be impactful for codebases that are not using lockfiles.

## Usages of `globalMutableWebpackConfig` must be replaced with `generateWebpackConfig()`

The function will return the same object with less risk:

```js
// before
const { globalMutableWebpackConfig, merge } = require('shakapacker');

const customConfig = {
  module: {
    rules: [
      {
        test: require.resolve('jquery'),
        loader: 'expose-loader',
        options: { exposes: ['$', 'jQuery'] }
      }
    ]
  }
};

module.exports = merge(globalMutableWebpackConfig, customConfig);
```

```js
// after
const { generateWebpackConfig } = require('shakapacker');

const customConfig = {
  module: {
    rules: [
      {
        test: require.resolve('jquery'),
        loader: 'expose-loader',
        options: { exposes: ['$', 'jQuery'] }
      }
    ]
  }
};

// you can also pass your config directly to the generator function to have it merged in!
module.exports = merge(generateWebpackConfig(), customConfig);
```

## `additional_paths` are now stripped just like with `source_path`

This means going forward asset paths should be same regardless of their source:

```erb
<%# before %>
<%= image_pack_tag('marketing/images/people_looking_happy.png') %>

<%# after %>
<%= image_pack_tag('image/people_looking_happy.png') %>
```

## Misc. removals

In addition to the above, v8 has also removed a number of miscellaneous functions that no one is probably using anyway but technically could have been including:
  - `isArray` js utility function (just use `Array.isArray` directly)
  - `relative_url_root` config getter (it was never used)
  - `verify_file_existance` method (use `verify_file_existence` instead)
  - `https` option for `webpack-dev-server` (use `server: 'https'` instead)
