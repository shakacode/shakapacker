# Shakapacker

_Official, actively maintained successor to [rails/webpacker](https://github.com/rails/webpacker). Internal naming for `shakapacker` will continue to use `webpacker` where possible for v6. ShakaCode stands behind the long-term maintainence and development of this project for the Rails community._

* See [V6 Upgrade](./docs/v6_upgrade.md) for upgrading from v5 or prior v6 releases.

[![Ruby specs](https://github.com/shakacode/shakapacker/workflows/Ruby%20specs/badge.svg)](https://github.com/shakacode/shakapacker/actions)
[![Jest specs](https://github.com/shakacode/shakapacker/workflows/Jest%20specs/badge.svg)](https://github.com/shakacode/shakapacker/actions)
[![Rubocop](https://github.com/shakacode/shakapacker/workflows/Rubocop/badge.svg)](https://github.com/shakacode/shakapacker/actions)
[![JS lint](https://github.com/shakacode/shakapacker/workflows/JS%20lint/badge.svg)](https://github.com/shakacode/shakapacker/actions)

[![node.js](https://img.shields.io/badge/node-%3E%3D%2012.0.0-brightgreen.svg)](https://www.npmjs.com/package/shakapacker)
[![Gem](https://img.shields.io/gem/v/shakapacker.svg)](https://rubygems.org/gems/shakapacker)
[![npm version](https://badge.fury.io/js/shakapacker.svg)](https://badge.fury.io/js/shakapacker)

Webpacker makes it easy to use the JavaScript pre-processor and bundler [Webpack v5+](https://webpack.js.org/)
to manage application-like JavaScript in Rails. It can coexist with the asset pipeline,
leaving Webpack responsible solely for app-like JavaScript, or it can be used exclusively, making it also responsible for images, fonts, and CSS.

Check out 6.1.1+ for [SWC](https://swc.rs/) and [esbuild-loader](https://github.com/privatenumber/esbuild-loader) support! They are faster than Babel!

See a comparison of [webpacker with jsbundling-rails](https://github.com/rails/jsbundling-rails/blob/main/docs/comparison_with_webpacker.md).

Discussion forum and Slack to discuss debugging and troubleshooting tips. Please open issues for bugs and feature requests:
1. [Discussions tab](https://github.com/shakacode/shakapacker/discussions)
2. [Slack discussion channel](https://reactrails.slack.com/join/shared_invite/enQtNjY3NTczMjczNzYxLTlmYjdiZmY3MTVlMzU2YWE0OWM0MzNiZDI0MzdkZGFiZTFkYTFkOGVjODBmOWEyYWQ3MzA2NGE1YWJjNmVlMGE)
3. [Tweets with tag `#shakapacker`](https://twitter.com/hashtag/shakapacker?src=hashtag_click)

[ShakaCode](https://www.shakacode.com) offers support for upgrading from webpacker and using Shakapacker. If interested, contact Justin Gordon, [justin@shakacode.com](mailto:justin@shakacode.com). ShakaCode is [hiring passionate engineers](https://jobs.lever.co/shakacode/3bdbfdb3-4495-4611-a279-01dddb351abe) that love open source.

---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

  - [Prerequisites](#prerequisites)
  - [Features](#features)
    - [Optional support](#optional-support)
  - [Installation](#installation)
    - [Rails v6+](#rails-v6)
    - [Note for Yarn v2 usage](#note-for-yarn-v2-usage)
  - [Concepts](#concepts)
  - [Usage](#usage)
    - [Configuration and Code](#configuration-and-code)
    - [View Helpers](#view-helpers)
      - [View Helpers `javascript_pack_tag` and `stylesheet_pack_tag`](#view-helpers-javascript_pack_tag-and-stylesheet_pack_tag)
      - [View Helper `append_javascript_pack_tag` and `append_stylesheet_pack_tag`](#view-helper-append_javascript_pack_tag-and-append_stylesheet_pack_tag)
      - [View Helper: `asset_pack_path`](#view-helper-asset_pack_path)
      - [View Helper: `image_pack_tag`](#view-helper-image_pack_tag)
      - [View Helper: `favicon_pack_tag`](#view-helper-favicon_pack_tag)
      - [View Helper: `preload_pack_asset`](#view-helper-preload_pack_asset)
    - [Images in Stylesheets](#images-in-stylesheets)
    - [Server-Side Rendering (SSR)](#server-side-rendering-ssr)
    - [Development](#development)
      - [Automatic Webpack Code Building](#automatic-webpack-code-building)
      - [Compiler strategies](#compiler-strategies)
      - [Common Development Commands](#common-development-commands)
    - [Webpack Configuration](#webpack-configuration)
    - [Babel configuration](#babel-configuration)
    - [SWC configuration](#swc-configuration)
    - [esbuild loader configuration](#esbuild-loader-configuration)
    - [Integrations](#integrations)
      - [React](#react)
      - [Typescript](#typescript)
      - [CoffeeScript](#coffeescript)
      - [TypeScript](#typescript)
      - [CSS](#css)
      - [Postcss](#postcss)
      - [Sass](#sass)
      - [Less](#less)
      - [Stylus](#stylus)
      - [Other frameworks](#other-frameworks)
    - [Custom Rails environments](#custom-rails-environments)
    - [Upgrading](#upgrading)
    - [Paths](#paths)
    - [Additional paths](#additional-paths)
  - [Deployment](#deployment)
  - [Example Apps](#example-apps)
  - [Troubleshooting](#troubleshooting)
  - [Contributing](#contributing)
  - [License](#license)
- [Supporters](#supporters)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Prerequisites

- Ruby 2.6+
- Rails 5.2+
- Node.js 12.13.0+ || 14+
- Yarn

## Features
- Rails view helpers that fully support Webpack output, including HMR and code splitting.
- Convenient but not required webpack configuration. The only requirement is that your webpack configuration create a manifest.
- HMR with the webpack-dev-server, such as for hot-reloading React!
- Automatic code splitting using multiple entry points to optimize JavaScript downloads.
- [Webpack v5+](https://webpack.js.org/)
- ES6 with [babel](https://babeljs.io/), [SWC](https://swc.rs/), or [Esbuild](https://github.com/privatenumber/esbuild-loader)
- Asset compression, source-maps, and minification
- CDN support
- Extensible and configurable. For example, all major dependencies are specified as peers, so you can upgrade easily.

### Optional support
 _Requires extra packages to be installed._
 - React
 - TypeScript
 - Stylesheets - Sass, Less, Stylus and Css, PostCSS
 - CoffeeScript

## Installation

### Rails v6+

With Rails v6+, skip JavaScript for a new app and follow below Manual Installation Steps to manually add the `shakapacker` gem to your Gemfile.
```bash
rails new myapp --skip-javascript
```

_Note, Rails 6 installs the older v5 version of webpacker unless you specify `--skip-javascript`._

Add `shakapacker` gem to your `Gemfile`:

```bash
bundle add shakapacker --strict
```

Then running the following to install Webpacker:

```bash
./bin/bundle install
./bin/rails webpacker:install
```

When `package.json` and/or `yarn.lock` changes, such as when pulling down changes to your local environment in a team settings, be sure to keep your NPM packages up-to-date:

```bash
yarn
```

Note, in v6+, most JS packages are peer dependencies. Thus, the installer will add the packages:

```bash
yarn add @babel/core @babel/plugin-transform-runtime @babel/preset-env @babel/runtime babel-loader \
  compression-webpack-plugin terser-webpack-plugin \
  webpack webpack-assets-manifest webpack-cli webpack-merge webpack-sources webpack-dev-server
```

Previously, these "webpack" and "babel" packages were direct dependencies for `webpacker`. By
making these peer dependencies, you have control over the versions used in your webpack and babel configs.

### Note for Yarn v2 usage

If you are using Yarn v2 (berry), please note that PnP modules are not supported.

In order to use Shakapacker with Yarn v2, make sure you set `nodeLinker: node-modules` in your `.yarnrc.yml` file as per the [Yarn docs](https://yarnpkg.com/getting-started/migration#step-by-step) to opt out of Plug'n'Play behaviour.

## Concepts

At it's core, Shakapacker's essential functionality is to:

1. Provide configuration by a single file used by both Rails view helpers and JavaScript webpack compilation code.
2. Provide Rails view helpers, utilizing this configuration file, so that a webpage can load JavaScript, CSS, and other static assets compiled by webpack, supporting bundle splitting, fingerprinting, and HMR.
3. Provide a community supported, default webpack compilation that generates the necessary bundles and manifest, using the same configuration file. This compilation can be extended for any needs.

## Usage

### Configuration and Code

You will need your file system to correspond to the setup of your `webpacker.yml` file.

Suppose you have the following configuration:

`webacker.yml`
```yml
default: &default
  source_path: app/javascript
  source_entry_path: packs 
  public_root_path: public
  public_output_path: packs
  nested_entries: false
# And more
```

And that maps to a directory structure like this:

```
app/javascript:
  └── packs:               # sets up webpack entries
  │   └── application.js   # references ../src/my_component.js
  │   └── application.css
  └── src:                 # any directory name is fine. Referenced files need to be under source_path
  │   └── my_component.js
  └── stylesheets:
  │   └── my_styles.css
  └── images:
      └── logo.svg
public/packs                # webpack output
```

Webpack intelligently includes only necessary files. In this example, the file `packs/application.js` would reference `../src/my_component.js`

`nested_entries` allows you to have webpack entry points nested in subdirectories. This defaults to false so you don't accidentally create entry points for an entire tree of files. In other words, with `nested_entries: false`, you can have your entire `source_path` used for your source (using the `source_entry_path: /`) and you place files at the top level that you want as entry points. `nested_entries: true` allows you to have entries that are in subdirectories. This is useful if you have entries that are generated, so you can have a `generated` subdirectory and easily separate generated files from the rest of your codebase.

### View Helpers
The Shakapacker view helpers generate the script and link tags to get the webpack output onto your views.

Be sure to consult the API documentation in the source code of [helper.rb](./lib/webpacker/helper.rb).

**Note:** In order for your styles or static assets files to be available in your view, you would need to link them in your "pack" or entry file. Otherwise, Webpack won't know to package up those files.

#### View Helpers `javascript_pack_tag` and `stylesheet_pack_tag`

These view helpers take your `webpacker.yml` configuration file, along with the resulting webpack compilation `manifest.json` and generates the HTML to load the assets.

You can then link the JavaScript pack in Rails views using the `javascript_pack_tag` helper. If you have styles imported in your pack file, you can link them by using `stylesheet_pack_tag`:

```erb
<%= javascript_pack_tag 'application' %>
<%= stylesheet_pack_tag 'application' %>
```

The `javascript_pack_tag` and `stylesheet_pack_tag` helpers will include all the transpiled
packs with the chunks in your view, which creates html tags for all the chunks.

You can provide multiple packs and other attributes. Note, `defer` defaults to showing.

```erb
<%= javascript_pack_tag 'calendar', 'map', 'data-turbolinks-track': 'reload' %>
```

The resulting HTML would look like:
```
<script src="/packs/vendor-16838bab065ae1e314.js" data-turbolinks-track="reload" defer></script>
<script src="/packs/calendar~runtime-16838bab065ae1e314.js" data-turbolinks-track="reload" defer></script>
<script src="/packs/calendar-1016838bab065ae1e314.js" data-turbolinks-track="reload" defer"></script>
<script src="/packs/map~runtime-16838bab065ae1e314.js" data-turbolinks-track="reload" defer></script>
<script src="/packs/map-16838bab065ae1e314.js" data-turbolinks-track="reload" defer></script>
```

In this output, both the calendar and map codes might refer to other common libraries. Those get placed something like the vendor bundle. The view helper removes any duplication.

Note, the default of "defer" for the `javascript_pack_tag`. You can override that to `false`. If you expose jquery globally with `expose-loader,` by using `import $ from "expose-loader?exposes=$,jQuery!jquery"` in your `app/javascript/application.js`, pass the option `defer: false` to your `javascript_pack_tag`.

**Important:** Pass all your pack names as multiple arguments, not multiple calls, when using `javascript_pack_tag` and the `stylesheet_pack_tag`. Otherwise, you will get duplicated chunks on the page. 

```erb
<%# DO %>
<%= javascript_pack_tag 'calendar', 'map' %>

<%# DON'T %>
<%= javascript_pack_tag 'calendar' %>
<%= javascript_pack_tag 'map' %>
```
While this also generally applies to `stylesheet_pack_tag`, you may use multiple calls to stylesheet_pack_tag if, say, you require multiple <style> tags for different output media:

``` erb
<%= stylesheet_pack_tag 'application', media: 'screen' %>
<%= stylesheet_pack_tag 'print', media: 'print' %>
```

#### View Helper `append_javascript_pack_tag` and `append_stylesheet_pack_tag`

If you need configure your script pack names or stylesheet pack names from the view for a route or partials, then you will need some logic to ensure you call the helpers only once with multiple arguments. The new view helpers, `append_javascript_pack_tag` and `append_stylesheet_pack_tag` can solve this problem. The helper `append_javascript_pack_tag` will queue up script packs when the `javascript_pack_tag` is finally used. Similarly,`append_stylesheet_pack_tag` will queue up style packs when the `stylesheet_pack_tag` is finally used.

Main view:
```erb
<% append_javascript_pack_tag 'calendar' %>
<% append_stylesheet_pack_tag 'calendar' %>
```

Some partial:
```erb
<% append_javascript_pack_tag 'map' %>
<% append_stylesheet_pack_tag 'map' %>
```

And the main layout has:
```erb
<%= javascript_pack_tag 'application' %>
<%= stylesheet_pack_tag 'application' %>
```

is the same as using this in the main layout:

```erb
<%= javascript_pack_tag 'calendar', 'map', application' %>
<%= stylesheet_pack_tag 'calendar', 'map', application' %>
```

However, you typically can't do that in the main layout, as the view and partial codes will depend on the route.

Thus, you can distribute the logic of what packs are needed for any route. All the magic of splitting up the code and CSS was automatic!

**Important:** Both `append_(javascript/stylesheet)_pack_tag` helpers can be used anywhere in your application as long as they are executed BEFORE `(javascript/stylesheet)_pack_tag` respectively. If you attempt to call one of the `append_(javascript/stylesheet)_pack_tag` helpers after the respective `(javascript/stylesheet)_pack_tag`, an error will be raised.

The typical issue is that your layout might reference some partials that need to configure packs. A good way to solve this problem is to use `content_for` to ensure that the code to render your partial comes before the call to `javascript_pack_tag`.

```erb
<% content_for :footer do 
   render 'shared/footer' %>
   
<%= javascript_pack_tag %>

<%= content_for :footer %>
```

For alternative options of setting the additional packs, [see this discussion](https://github.com/shakacode/shakapacker/issues/39).

#### View Helper: `asset_pack_path`

If you want to link a static asset for `<img />` tag, you can use the `asset_pack_path` helper:
```erb
<img src="<%= asset_pack_path 'static/logo.svg' %>" />
```

#### View Helper: `image_pack_tag`

Or use the dedicated helper:
```erb
<%= image_pack_tag 'application.png', size: '16x10', alt: 'Edit Entry' %>
<%= image_pack_tag 'picture.png', srcset: { 'picture-2x.png' => '2x' } %>
```

#### View Helper: `favicon_pack_tag`
If you want to create a favicon:
```erb
<%= favicon_pack_tag 'mb-icon.png', rel: 'apple-touch-icon', type: 'image/png' %>
```

#### View Helper: `preload_pack_asset`
If you want to preload a static asset in your `<head>`, you can use the `preload_pack_asset` helper:
```erb
<%= preload_pack_asset 'fonts/fa-regular-400.woff2' %>
```


### Images in Stylesheets
If you want to use images in your stylesheets:

```css
.foo {
  background-image: url('../images/logo.svg')
}
```

### Server-Side Rendering (SSR)

Note, if you are using server-side rendering of JavaScript with dynamic code-splitting, as is often done with extensions to Webpacker, like [React on Rails](https://github.com/shakacode/react_on_rails), your JavaScript should create the link prefetch HTML tags that you will use, so you won't need to use to `asset_pack_path` in those circumstances.

### Development

Webpacker ships with two binstubs: `./bin/webpacker` and `./bin/webpacker-dev-server`. Both are thin wrappers around the standard `webpack.js` and `webpack-dev-server.js` executables to ensure that the right configuration files and environmental variables are loaded based on your environment.

#### Automatic Webpack Code Building

Shakapacker can be configured to automatically compile on demand when needed using the `webpacker.yml` `compile` option. This happens when you refer to any of the pack assets using the Shakapacker helper methods. This means that you don't have to run any separate processes. Compilation errors are logged to the standard Rails log. However, this auto-compilation happens when a web request is made that requires an updated webpack build, not when files change. Thus, that can be **painfully slow** for front-end development in this default way. Instead, you should either run the `bin/webpacker --watch` or run `./bin/webpacker-dev-server` during development.

The `compile: true` option can be more useful for test and production builds.

#### Compiler strategies

Shakapacker ships with two different strategies that are used to determine whether assets need recompilation per the `compile: true` option:

- `digest` - This strategy calculates SHA1 digest of files in your watched paths (see below). The calculated digest is then stored in a temp file. To check whether the assets need to be recompiled, Shakapacker calculates the SHA1 of the watched files and compares it with the one stored. If the digests are equal, no recompilation occurs. If the digests are different or the temp file is missing, files are recompiled.
- `mtime` - This strategy looks at last modified at timestamps of both files AND directories in your watched paths. The timestamp of the most recent file or directory is then compared with the timestamp of `manifest.json` file generated. If the manifest file timestamp is newer than one of the most recently modified file or directory in the watched paths, no recompilation occurs. If the manifest file is order, files are recompiled.

The `mtime` strategy is generally faster than the `digest` one, but it requires stable timestamps, this makes it perfect for a development environment, such as needing to rebuild bundles for tests, or if you're not changing frontend assets much.

In production or CI environments, the `digest` strategy is more suitable, unless you are using incremental builds or caching and can guarantee that the timestamps will not change after e.g. cache restore. However, many production or CI environments will explicitly compile assets, so `compile: false` is more appropriate. Otherwise, you'll waste time either checking file timestamps or computing digests.

You can control what strategy is used by `compiler_strategy` option in `webpacker.yml` config file. By default `mtime` strategy is used in development environment, `digest` is used elsewhere.

**Note:** If you are not using the webpack-dev-server, your packs will be served by Rails public file server. If you've enabled caching (Rails application `config.action_controller.perform_caching` setting), your changes will likely not be picked up due to `Cache-Control` header being set and assets being cached in browser memory. For more details see the [issue #88](https://github.com/shakacode/shakapacker/issues/88).

If you want to use live code reloading, or you have enough JavaScript that on-demand compilation is too slow, you'll need to run `./bin/webpacker-dev-server`. This process will watch for changes in the relevant files, defined by `webpacker.yml` configuration settings for `source_path`, `source_entry_path`, and `additional_paths`, and it will then automatically reload the browser to match. This feature is also known as [Hot Module Replacement](https://webpack.js.org/concepts/hot-module-replacement/).

#### Common Development Commands

```bash
# webpack dev server
./bin/webpacker-dev-server

# watcher
./bin/webpacker --watch --progress

# standalone build
./bin/webpacker --progress
```

Once you start this webpack development server, Webpacker will automatically start proxying all webpack asset requests to this server. When you stop this server, Rails will detect that it's not running and Rails will revert back to on-demand compilation _if_ you have the `compile` option set to true in your `config/webpacker.yml`

You can use environment variables as options supported by [webpack-dev-server](https://webpack.js.org/configuration/dev-server/) in the form `WEBPACKER_DEV_SERVER_<OPTION>`. Please note that these environmental variables will always take precedence over the ones already set in the configuration file, and that the _same_ environmental variables must be available to the `rails server` process.

```bash
WEBPACKER_DEV_SERVER_PORT=4305 WEBPACKER_DEV_SERVER_HOST=example.com WEBPACKER_DEV_SERVER_INLINE=true WEBPACKER_DEV_SERVER_HOT=false ./bin/webpacker-dev-server
```

By default, the webpack dev server listens on `localhost:3035` in development for security purposes. However, if you want your app to be available on port 4035 over local LAN IP or a VM instance like vagrant, you can set the `port` and `host` when running `./bin/webpacker-dev-server` binstub:

```bash
WEBPACKER_DEV_SERVER_PORT=4305 WEBPACKER_DEV_SERVER_HOST=0.0.0.0 ./bin/webpacker-dev-server
```

**Note:** You need to allow webpack-dev-server host as an allowed origin for `connect-src` if you are running your application in a restrict CSP environment (like Rails 5.2+). This can be done in Rails 5.2+ in the CSP initializer `config/initializers/content_security_policy.rb` with a snippet like this:

```ruby
Rails.application.config.content_security_policy do |policy|
  policy.connect_src :self, :https, 'http://localhost:3035', 'ws://localhost:3035' if Rails.env.development?
end
```

**Note:** Don't forget to prefix `ruby` when running these binstubs on Windows


### Webpack Configuration

First, you don't _need_ to use Shakapacker's webpack configuration. However, the `shakapacker` NPM package provides convenient access to configuration code that reads the `config/webpacker.yml` file which the view helpers also use. If you have your own customized webpack configuration, at the minimum, you must ensure:

1. Your output files go the right directory
2. Your output includes a manifest, via package [`webpack-assets-manifest`](https://github.com/webdeveric/webpack-assets-manifest) that maps output names (your 'packs') to the fingerprinted versions, including bundle-splitting dependencies. That's the main secret sauce of webpacker!

The most practical webpack configuration is to take the default from Shakapacker and then use [webpack-merge](https://github.com/survivejs/webpack-merge) to merge your customizations with the default. For example, suppose you want to add some `resolve.extensions`:

```js
// use the new NPM package name, `shakapacker`.
// merge is webpack-merge from https://github.com/survivejs/webpack-merge
const { webpackConfig: baseWebpackConfig, merge } = require('shakapacker')

const options = {
  resolve: {
      extensions: ['.css', '.ts', '.tsx']
  }
}

// Copy the object using merge b/c the baseClientWebpackConfig is a mutable global
// If you want to use this object for client and server rendering configurations,
// havaing a new object is essential.
module.exports = merge({}, baseWebpackConfig, options)
```

This example is based on [an example project](https://github.com/shakacode/react_on_rails_tutorial_with_ssr_and_hmr_fast_refresh/blob/master/config/webpack/webpack.config.js)

Shakapacker gives you a default configuration file `config/webpack/webpack.config.js`, which, by default, you don't need to make any changes to `config/webpack/webpack.config.js` since it's a standard production-ready configuration. However, you will probably want to customize or add a new loader by modifying the webpack configuration, as shown above.

You might add separate files to keep your code more organized.

```js
// config/webpack/custom.js
module.exports = {
  resolve: {
    alias: {
      jquery: 'jquery/src/jquery',
      vue: 'vue/dist/vue.js',
      React: 'react',
      ReactDOM: 'react-dom',
      vue_resource: 'vue-resource/dist/vue-resource'
    }
  }
}
```

Then `require` this file in your `config/webpack/webpack.config.js`:

```js
// config/webpack/webpack.config.js
// use the new NPM package name, `shakapacker`.
const { webpackConfig, merge } = require('shakapacker')
const customConfig = require('./custom')

module.exports = merge(webpackConfig, customConfig)
```

If you need access to configs within Shakapacker's configuration, you can import them like so:

```js
// config/webpack/webpack.config.js
const { webpackConfig } = require('shakapacker')

console.log(webpackConfig.output_path)
console.log(webpackConfig.source_path)

// Or to print out your whole webpack configuration
console.log(JSON.stringify(webpackConfig, undefined, 2))
```

You may want to modify rules in the default configuration. For instance, if you are using a custom svg loader, you may want to remove `.svg` from the default file loader rules. You can search and filter the default rules like so:

```js
const svgRule = config.module.rules.find(rule => rule.test.test('.svg'));
svgRule.test = svgRule.test.filter(t => !t.test('.svg'))
```

### Babel configuration

By default, you will find the Shakapacker preset in your `package.json`. Note, you need to use the new NPM package name, `shakapacker`.

```json
"babel": {
  "presets": [
    "./node_modules/shakapacker/package/babel/preset.js"
  ]
},
```
Optionally, you can change your Babel configuration by removing these lines in your `package.json` and add [a Babel configuration file](https://babeljs.io/docs/en/config-files) in your project. For an example customization based on the original, see [Customizing Babel Config](./docs/customizing_babel_config.md).


### SWC configuration

You can try out experimental integration with the SWC loader. You can read more at [SWC usage docs](./docs/using_swc_loader.md).

Please note that if you want opt-in to use SWC, you can skip [React](#react) integration instructions as it is supported out of the box.

### esbuild loader configuration

You can try out experimental integration with the esbuild-loader. You can read more at [esbuild-loader usage docs](./docs/using_esbuild_loader.md).

Please note that if you want opt-in to use esbuild-loader, you can skip [React](#react) integration instructions as it is supported out of the box.

### Integrations

Shakapacker out of the box supports JS and static assets (fonts, images etc.) compilation. To enable support for CoffeeScript or TypeScript install relevant packages:

#### React

See here for detailed instructions on how to [configure Shakapacker to bundle a React app](./docs/react.md) (with optional HMR).

See also [Customizing Babel Config](./docs/customizing_babel_config.md) for an example React configuration.

#### Typescript
...if you are using typescript, update your `tsconfig.json`

```json
{
  "compilerOptions": {
    "declaration": false,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "lib": ["es6", "dom"],
    "module": "es6",
    "moduleResolution": "node",
    "sourceMap": true,
    "target": "es5",
    "jsx": "react",
    "noEmit": true
  },
  "exclude": ["**/*.spec.ts", "node_modules", "vendor", "public"],
  "compileOnSave": false
}
```

#### CoffeeScript

```bash
yarn add coffeescript coffee-loader
```

#### TypeScript

```bash
yarn add typescript @babel/preset-typescript
```

Babel won’t perform any type-checking on TypeScript code. To optionally use type-checking run:

```bash
yarn add fork-ts-checker-webpack-plugin
```

Add tsconfig.json

```json
{
  "compilerOptions": {
    "declaration": false,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "lib": ["es6", "dom"],
    "module": "es6",
    "moduleResolution": "node",
    "baseUrl": ".",
    "paths": {
      "*": ["node_modules/*", "app/javascript/*"]
    },
    "sourceMap": true,
    "target": "es5",
    "noEmit": true
  },
  "exclude": ["**/*.spec.ts", "node_modules", "vendor", "public"],
  "compileOnSave": false
}
```

Then modify the webpack config to use it as a plugin:

```js
// config/webpack/webpack.config.js
const { webpackConfig, merge } = require("shakapacker");
const ForkTSCheckerWebpackPlugin = require("fork-ts-checker-webpack-plugin");

module.exports = merge(webpackConfig, {
  plugins: [new ForkTSCheckerWebpackPlugin()],
});
```

#### CSS

To enable CSS support in your application, add following packages:

```bash
yarn add css-loader style-loader mini-css-extract-plugin css-minimizer-webpack-plugin
```

Optionally, add the `CSS` extension to webpack config for easy resolution.

```js
// config/webpack/webpack.config.js
const { webpackConfig, merge } = require('shakapacker')
const customConfig = {
  resolve: {
    extensions: ['.css']
  }
}

module.exports = merge(webpackConfig, customConfig)
```

To enable `PostCSS`, `Sass` or `Less` support, add `CSS` support first and
then add the relevant pre-processors:

#### Postcss

```bash
yarn add postcss postcss-loader
```

Optionally add these two plugins if they are required in your `postcss.config.js`:
```bash
yarn add postcss-preset-env postcss-flexbugs-fixes
```

#### Sass

```bash
yarn add sass sass-loader
```

#### Less

```bash
yarn add less less-loader
```

#### Stylus

```bash
yarn add stylus stylus-loader
```

#### Other frameworks

Please follow webpack integration guide for relevant framework or library,

1. [Svelte](https://github.com/sveltejs/svelte-loader#install)
2. [Angular](https://v2.angular.io/docs/ts/latest/guide/webpack.html#!#configure-webpack)
3. [Vue](https://vue-loader.vuejs.org/guide/)

For example to add Vue support:
```js
// config/webpack/rules/vue.js
const { VueLoaderPlugin } = require('vue-loader')

module.exports = {
  module: {
    rules: [
      {
        test: /\.vue$/,
        loader: 'vue-loader'
      }
    ]
  },
  plugins: [new VueLoaderPlugin()],
  resolve: {
    extensions: ['.vue']
  }
}
```

```js
// config/webpack/webpack.config.js
const { webpackConfig, merge } = require('shakapacker')
const vueConfig = require('./rules/vue')

module.exports = merge(vueConfig, webpackConfig)
```

### Custom Rails environments

Out of the box Shakapacker ships with - development, test and production environments in `config/webpacker.yml` however, in most production apps extra environments are needed as part of deployment workflow. Shakapacker supports this out of the box from version 3.4.0+ onwards.

You can choose to define additional environment configurations in webpacker.yml,

```yml
staging:
  <<: *default

  # Production depends on precompilation of packs prior to booting for performance.
  compile: false

  # Cache manifest.json for performance
  cache_manifest: true

  # Compile staging packs to a separate directory
  public_output_path: packs-staging
```

Otherwise Shakapacker will use production environment as a fallback environment for loading configurations. Please note, `NODE_ENV` can either be set to `production`, `development` or `test`. This means you don't need to create additional environment files inside `config/webpacker/*` and instead use webpacker.yml to load different configurations using `RAILS_ENV`.

For example, the below command will compile assets in production mode but will use staging configurations from `config/webpacker.yml` if available or use fallback production environment configuration:

```bash
RAILS_ENV=staging bundle exec rails assets:precompile
```

And, this will compile in development mode and load configuration for cucumber environment if defined in webpacker.yml or fallback to production configuration

```bash
RAILS_ENV=cucumber NODE_ENV=development bundle exec rails assets:precompile
```

Please note, binstubs compiles in development mode however rake tasks compiles in production mode.

```bash
# Compiles in development mode unless NODE_ENV is specified, per the binstub source
./bin/webpacker
./bin/webpacker-dev-server

# Compiles in production mode by default unless NODE_ENV is specified, per `lib/tasks/webpacker/compile.rake`
bundle exec rails assets:precompile
bundle exec rails webpacker:compile
```

### Upgrading

You can run following commands to upgrade Shakapacker to the latest stable version. This process involves upgrading the gem and related JavaScript packages:

```bash
# check your Gemfile for version restrictions
bundle update shakapacker

# overwrite your changes to the default install files and revert any unwanted changes from the install
rails webpacker:install

# yarn 1 instructions
yarn upgrade shakapacker --latest
yarn upgrade webpack-dev-server --latest

# yarn 2 instructions
yarn up shakapacker@latest
yarn up webpack-dev-server@latest

# Or to install the latest release (including pre-releases)
yarn add shakapacker@next
```

Also, consult the [CHANGELOG](./CHANGELOG.md) for additional upgrade links.

### Paths

By default, Shakapacker ships with simple conventions for where the JavaScript app files and compiled webpack bundles will go in your Rails app. All these options are configurable from `config/webpacker.yml` file.

The configuration for what webpack is supposed to compile by default rests on the convention that every file in `app/javascript/`**(default)** or whatever path you set for `source_entry_path` in the `webpacker.yml` configuration is turned into their own output files (or entry points, as webpack calls it). Therefore you don't want to put any file inside `app/javascript` directory that you do not want to be an entry file. As a rule of thumb, put all files you want to link in your views inside "app/javascript/" directory and keep everything else under subdirectories like `app/javascript/controllers`.

Suppose you want to change the source directory from `app/javascript` to `frontend` and output to `assets/packs`. This is how you would do it:

```yml
# config/webpacker.yml
source_path: frontend # packs are the files in frontend/
public_output_path: assets/packs # outputs to => public/assets/packs
```

Similarly you can also control and configure `webpack-dev-server` settings from `config/webpacker.yml` file:

```yml
# config/webpacker.yml
development:
  dev_server:
    host: localhost
    port: 3035
```

If you have `hmr` turned to true and `inline_css` is not false, then the `stylesheet_pack_tag` generates no output, as you will want to configure your styles to be inlined in your JavaScript for hot reloading. During production and testing, the `stylesheet_pack_tag` will create the appropriate HTML tags.

If you want to have HMR and separate link tags, set `hmr: true` and `inline_css: false`. This will cause styles to be extracted and reloaded with the `mini-css-extract-plugin` loader. Note that in this scenario, you do not need to include style-loader in your project dependencies.

### Additional paths

If you are adding Shakapacker to an existing app that has most of the assets inside `app/assets` or inside an engine, and you want to share that with webpack modules, you can use the `additional_paths` option available in `config/webpacker.yml`. This lets you
add additional paths that webpack should look up when resolving modules:

```yml
additional_paths: ['app/assets', 'vendor/assets']
```

You can then import these items inside your modules like so:

```js
// Note it's relative to parent directory i.e. app/assets
import 'stylesheets/main'
import 'images/rails.png'
```

**Note:** Please be careful when adding paths here otherwise it will make the compilation slow, consider adding specific paths instead of whole parent directory if you just need to reference one or two modules

**Also note:** While importing assets living outside your `source_path` defined in webpacker.yml (like, for instance, assets under `app/assets`) from within your packs using _relative_ paths like `import '../../assets/javascripts/file.js'` will work in development, Shakapacker won't recompile the bundle in production unless a file that lives in one of it's watched paths has changed (check out `Webpacker::MtimeStrategy#latest_modified_timestamp` or `Webpacker::DigestStrategy#watched_files_digest` depending on strategy configured by `compiler_strategy` option in `webpacker.yml`). That's why you'd need to add `app/assets` to the additional_paths as stated above and use `import 'javascripts/file.js'` instead.


## Deployment

Shakapacker hooks up a new `webpacker:compile` task to `assets:precompile`, which gets run whenever you run `assets:precompile`. If you are not using Sprockets, `webpacker:compile` is automatically aliased to `assets:precompile`. Similar to sprockets both rake tasks will compile packs in production mode but will use `RAILS_ENV` to load configuration from `config/webpacker.yml` (if available).

This behavior is optional & can be disabled by either setting an `WEBPACKER_PRECOMPILE` environment variable to `false`, `no`, `n`, or `f`, or by setting a `webpacker_precompile` key in your `webpacker.yml` to `false`. ([source code](./lib/webpacker/configuration.rb#L30))

When compiling assets for production on a remote server, such as a continuous integration environment, it's recommended to use `yarn install --frozen-lockfile` to install NPM packages on the remote host to ensure that the installed packages match the `yarn.lock` file.

If you are using a CDN setup, webpacker will use the configured [asset host](https://guides.rubyonrails.org/configuring.html#rails-general-configuration) value to prefix URLs for images or font icons which are included inside JS code or CSS. It is possible to override this value during asset compilation by setting the `WEBPACKER_ASSET_HOST` environment variable.

## Example Apps
* [React on Rails Tutorial With SSR, HMR fast refresh, and TypeScript](https://github.com/shakacode/react_on_rails_tutorial_with_ssr_and_hmr_fast_refresh)


## Troubleshooting

See the doc page for [Troubleshooting](./docs/troubleshooting.md).

## Contributing

We encourage you to contribute to Shakapacker/Webpacker! See [CONTRIBUTING](CONTRIBUTING.md) for guidelines about how to proceed. We have a [Slack discussion channel](https://reactrails.slack.com/join/shared_invite/enQtNjY3NTczMjczNzYxLTlmYjdiZmY3MTVlMzU2YWE0OWM0MzNiZDI0MzdkZGFiZTFkYTFkOGVjODBmOWEyYWQ3MzA2NGE1YWJjNmVlMGE).

## License

Webpacker is released under the [MIT License](https://opensource.org/licenses/MIT).
  
# Supporters

The following companies support this open source project, and ShakaCode uses their products! Justin writes React on Rails on [RubyMine](https://www.jetbrains.com/ruby/). We use [Scout](https://scoutapp.com/) to monitor the live performance of [HiChee.com](https://HiChee.com), [Rails AutoScale](https://railsautoscale.com) to scale the dynos of HiChee, and [HoneyBadger](https://www.honeybadger.io/) to monitor application errors. We love [BrowserStack](https://www.browserstack.com) to solve problems with oddball browsers.

[![RubyMine](https://user-images.githubusercontent.com/1118459/114100597-3b0e3000-9860-11eb-9b12-73beb1a184b2.png)](https://www.jetbrains.com/ruby/)
[![Scout](https://user-images.githubusercontent.com/1118459/171088197-81555b69-9ed0-4235-9acf-fcb37ecfb949.png)](https://scoutapp.com/)
[![Rails AutoScale](https://user-images.githubusercontent.com/1118459/103197530-48dc0e80-488a-11eb-8b1b-a16664b30274.png)](https://railsautoscale.com/)
[![BrowserStack](https://cloud.githubusercontent.com/assets/1118459/23203304/1261e468-f886-11e6-819e-93b1a3f17da4.png)](https://www.browserstack.com)
[![HoneyBadger](https://user-images.githubusercontent.com/1118459/114100696-63962a00-9860-11eb-8ac1-75ca02856d8e.png)](https://www.honeybadger.io/)

ShakaCode's favorite project tracking tool is [Shortcut](https://shortcut.com/). If you want to **try Shortcut and get 2 months free beyond the 14-day trial period**, click [here to use ShakaCode's referral code](http://r.clbh.se/mvfoNeH). We're participating in their awesome triple-sided referral program, which you can read about [here](https://shortcut.com/referral/). By using our [referral code](http://r.clbh.se/mvfoNeH) you'll be supporting ShakaCode and, thus, React on Rails!
