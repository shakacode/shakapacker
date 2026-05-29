# Node Package API

Shakapacker ships a Node package that exposes configuration and helper utilities
for both webpack and rspack.

## Import Paths

```js
// Webpack entrypoint
const shakapacker = require("shakapacker")

// Rspack entrypoint
const rspack = require("shakapacker/rspack")
```

## Webpack Exports (`shakapacker`)

| Export                                                    | Type      | Description                                                  |
| --------------------------------------------------------- | --------- | ------------------------------------------------------------ |
| `config`                                                  | object    | Parsed `config/shakapacker.yml` plus computed fields         |
| `devServer`                                               | object    | Dev server configuration                                     |
| `generateWebpackConfig(extraConfig?)`                     | function  | Generates final webpack config and merges optional overrides |
| `baseConfig`                                              | object    | Base config object from `package/environments/base`          |
| `env`                                                     | object    | Environment metadata (`railsEnv`, `nodeEnv`, booleans)       |
| `rules`                                                   | array     | Loader rules for current bundler                             |
| `moduleExists(name)`                                      | function  | Returns whether module can be resolved                       |
| `canProcess(rule, fn)`                                    | function  | Runs callback only if loader dependency is available         |
| `inliningCss`                                             | boolean   | Whether CSS should be inlined in current dev-server mode     |
| `merge`, `mergeWithCustomize`, `mergeWithRules`, `unique` | functions | Re-exported from `webpack-merge`                             |

## Webpack Configuration Patterns

You do not need to use Shakapacker's generated webpack configuration. If you
provide a custom webpack configuration, the minimum requirements are:

1. Output files go to the configured directory.
2. The build writes a manifest, usually with
   [`webpack-assets-manifest`](https://github.com/webdeveric/webpack-assets-manifest),
   mapping pack names to fingerprinted output files and bundle-splitting
   dependencies.

The default webpack configuration lives in `config/webpack/webpack.config.js`.
By default, it exports the result of `generateWebpackConfig`, which generates a
webpack configuration from `config/shakapacker.yml`.

### Using a Completely Custom Webpack Configuration

If you provide a completely custom webpack configuration without
`generateWebpackConfig()`, set `javascript_transpiler: "none"` in
`config/shakapacker.yml` to skip Shakapacker's transpiler validation and
dependency checks:

```yaml
default: &default
  javascript_transpiler: "none"
```

Only use `javascript_transpiler: "none"` when your custom configuration owns the
loader setup entirely. If you use Shakapacker's webpack generation, use one of
the supported transpilers: `"babel"`, `"swc"`, or `"esbuild"`.

### Merge Custom Options

The easiest way to modify the generated config is to pass options to
`generateWebpackConfig`, which uses `webpack-merge` internally:

```js
// config/webpack/webpack.config.js
const { generateWebpackConfig } = require("shakapacker")

const options = {
  resolve: {
    extensions: [".css", ".ts", ".tsx"]
  }
}

module.exports = generateWebpackConfig(options)
```

For more advanced customizations, import `merge` directly:

```js
// config/webpack/webpack.config.js
const { generateWebpackConfig, merge } = require("shakapacker")

const webpackConfig = generateWebpackConfig()

const options = {
  resolve: {
    extensions: [".css", ".ts", ".tsx"]
  }
}

module.exports = merge(options, webpackConfig)
```

You can also split configuration into local files:

```js
// config/webpack/custom.js
module.exports = {
  resolve: {
    alias: {
      jquery: "jquery/src/jquery",
      vue: "vue/dist/vue.js",
      React: "react",
      ReactDOM: "react-dom",
      vue_resource: "vue-resource/dist/vue-resource"
    }
  }
}
```

```js
// config/webpack/webpack.config.js
const { generateWebpackConfig } = require("shakapacker")

const customConfig = require("./custom")

module.exports = generateWebpackConfig(customConfig)
```

If you need to inspect the generated configuration:

```js
// config/webpack/webpack.config.js
const { generateWebpackConfig } = require("shakapacker")

const webpackConfig = generateWebpackConfig()

console.log(webpackConfig.output_path)
console.log(webpackConfig.source_path)
console.log(JSON.stringify(webpackConfig, undefined, 2))
```

You can search and modify generated rules. For example, to remove `.svg` from a
file-loader-style asset rule:

```js
const fileRule = config.module.rules.find((rule) => rule.test.test(".svg"))
fileRule.test =
  /\.(bmp|gif|jpe?g|png|tiff|ico|avif|webp|eot|otf|ttf|woff|woff2)$/
fileRule.type = "asset"
```

## Rspack Exports (`shakapacker/rspack`)

| Export                                                    | Type      | Description                                                 |
| --------------------------------------------------------- | --------- | ----------------------------------------------------------- |
| `config`                                                  | object    | Parsed `config/shakapacker.yml` plus computed fields        |
| `devServer`                                               | object    | Dev server configuration                                    |
| `generateRspackConfig(extraConfig?)`                      | function  | Generates final rspack config and merges optional overrides |
| `baseConfig`                                              | object    | Base config object                                          |
| `env`                                                     | object    | Environment metadata (`railsEnv`, `nodeEnv`, booleans)      |
| `rules`                                                   | array     | Rspack loader rules                                         |
| `moduleExists(name)`                                      | function  | Returns whether module can be resolved                      |
| `canProcess(rule, fn)`                                    | function  | Runs callback only if loader dependency is available        |
| `inliningCss`                                             | boolean   | Whether CSS should be inlined in current dev-server mode    |
| `merge`, `mergeWithCustomize`, `mergeWithRules`, `unique` | functions | Re-exported from `webpack-merge`                            |

## `config` Object

`config` includes:

- Raw values from `config/shakapacker.yml` (`source_path`, `public_output_path`, `javascript_transpiler`, etc.)
- Computed absolute paths (`outputPath`, `publicPath`, `manifestPath`, `publicPathWithoutCDN`)
- Optional sections like `dev_server` and `integrity`

For the full key list and types, see:

- [`package/types.ts`](../package/types.ts)
- [Configuration Guide](./configuration.md)

## Built-in Third-Party Support

Installer defaults include support for:

- Bundlers: webpack, rspack
- JavaScript transpilers: SWC (default), Babel, esbuild
- Common style/tooling loaders: css, sass, less, stylus, file/raw rules
- Common optimization/plugins for webpack/rspack production builds

Dependency presets used by the installer are defined in:

- [`lib/install/package.json`](../lib/install/package.json)

### Optional Loader Packages

To enable CSS support in your application, add the relevant packages:

```bash
npm install css-loader style-loader mini-css-extract-plugin css-minimizer-webpack-plugin
```

Optionally add `.css` to webpack resolution:

```js
// config/webpack/webpack.config.js
const { generateWebpackConfig } = require("shakapacker")

const customConfig = {
  resolve: {
    extensions: [".css"]
  }
}

module.exports = generateWebpackConfig(customConfig)
```

PostCSS:

```bash
npm install postcss postcss-loader
npm install postcss-preset-env postcss-flexbugs-fixes
```

Sass:

```bash
npm install sass-loader
npm install sass
```

You can use Dart Sass (`sass`), Node Sass (`node-sass`), or Sass Embedded
(`sass-embedded`); `sass-loader` picks an implementation based on installed
packages.

Less:

```bash
npm install less less-loader
```

Stylus:

```bash
npm install stylus stylus-loader
```

CoffeeScript:

```bash
npm install coffeescript coffee-loader
```

### Other Frameworks

Follow the webpack integration guide for the relevant framework or library:

1. [Svelte](https://github.com/sveltejs/svelte-loader#install)
2. [Angular](https://v2.angular.io/docs/ts/latest/guide/webpack.html#!#configure-webpack)
3. [Vue](https://vue-loader.vuejs.org/guide/)

For example, to add Vue support:

```js
// config/webpack/rules/vue.js
const { VueLoaderPlugin } = require("vue-loader")

module.exports = {
  module: {
    rules: [
      {
        test: /\.vue$/,
        loader: "vue-loader"
      }
    ]
  },
  plugins: [new VueLoaderPlugin()],
  resolve: {
    extensions: [".vue"]
  }
}
```

```js
// config/webpack/webpack.config.js
const { generateWebpackConfig, merge } = require("shakapacker")

const webpackConfig = generateWebpackConfig()

const vueConfig = require("./rules/vue")

module.exports = merge(vueConfig, webpackConfig)
```
