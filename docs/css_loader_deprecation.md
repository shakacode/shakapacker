# css-loader Deprecation And Built-in CSS Support

`css-loader` and its companions are deprecated upstream. This page explains what
that does and does not mean for a Shakapacker app, what Shakapacker does today,
and what is still missing before built-in CSS can become the default.

## What actually happened

The webpack team archived the repositories for `css-loader`, `style-loader`, and
`mini-css-extract-plugin` in late August 2026, and added a deprecation banner to
the `css-loader` README pointing at webpack's
[Native CSS guide](https://webpack.js.org/guides/native-css/). webpack now parses
CSS itself and no longer needs the loader.

`css-minimizer-webpack-plugin` was archived earlier, on a separate track: its
README directs you to
[`minimizer-webpack-plugin`](https://github.com/webpack/minimizer-webpack-plugin#css),
which is actively released and is the same package webpack's own default
minimizer uses internally.

Two clarifications, because the wording upstream invites a stronger reading than
the facts support:

- **The packages are not deprecated on npm.** No published version carries an
  `npm deprecate` marker, and `css-loader@7.1.5` shipped the same week the
  repository was archived. Installs are not going to start printing warnings.
- **`postcss-loader` and `sass-loader` are not affected.** They are still
  actively developed, and preprocessors keep their loaders under built-in CSS
  too. Only the CSS-handling packages above are archived.

Archived means frozen, not broken. An app on the loader chain keeps working.

## Your existing app is not affected

Since webpack 5.109.0, `experiments.css` defaults to `'auto'`: built-in CSS turns
on **unless** a `module.rules` entry with a loader already matches `.css`.
Shakapacker registers exactly such a rule whenever `css-loader` is installed, so
built-in CSS stays off and nothing about your build changes. Class names,
emitted files, and `manifest.json` are all identical on webpack 5.110 to what
they were on 5.101.

You do not need to do anything.

## How Shakapacker picks a CSS path

Shakapacker chooses per build, based on whether `css-loader` resolves:

| `css-loader` installed | What Shakapacker emits                                                                                                                    |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Yes (default)          | The loader chain: `mini-css-extract-plugin`/`CssExtractRspackPlugin` (or `style-loader`) → `css-loader` → `postcss-loader` → preprocessor |
| No                     | `{ type: "css/auto" }` rules with `postcss-loader` → preprocessor still in `use`, so the bundler parses the CSS they produce              |

The installer adds `css-loader` to every new app, so the loader chain is what
you get unless you remove it deliberately.

### Opting into built-in CSS

Uninstall `css-loader`. Keep `postcss-loader` and any preprocessor loader — the
built-in parser replaces `css-loader`, not them:

```bash
yarn remove css-loader style-loader mini-css-extract-plugin
```

Shakapacker then emits `css/auto` rules for `.css` and for every preprocessor
extension, sets `experiments.css` on webpack, and points `output.cssFilename` at
the same `css/[name]-[contenthash:8].css` paths the extraction plugins used, so
`manifest.json` and `stylesheet_pack_tag` are unchanged.

PostCSS keeps running on both paths and in the same order: the preprocessor
compiles first, then `postcss-loader`, then the CSS is parsed. Autoprefixer,
`postcss-preset-env`, and Tailwind's PostCSS plugin are unaffected by the
switch.

`bundle exec rake shakapacker:doctor` reports which path a build is on.

## What carries over, and what changes

Shakapacker maps its own CSS settings onto the built-in parser:

| Shakapacker setting                | Loader chain                         | Built-in CSS                                   |
| ---------------------------------- | ------------------------------------ | ---------------------------------------------- |
| `css_modules_export_mode: named`   | `namedExport: true`, `camelCaseOnly` | `parser.namedExports: true`, `camel-case-only` |
| `css_modules_export_mode: default` | `namedExport: false`, `camelCase`    | `parser.namedExports: false`, `camel-case`     |
| `dev_server.inline_css: true`      | `style-loader`                       | `parser.exportType: "style"`                   |
| `dev_server.inline_css: false`     | extraction plugin                    | `exportType: "link"` (the default)             |

This matters: the built-in parser's own default for `exportsConvention` is
`as-is`, which would export `styles["my-button"]` rather than
`styles.myButton`. Shakapacker sets the convention explicitly so your imports do
not change.

Three things do change, and you should expect them:

1. **Generated CSS Modules class names differ.** The loader chain and the
   built-in generator use different `localIdentName` defaults. The names are
   opaque hashes either way, but anything that pins a generated class name — a
   snapshot test, a hardcoded selector in a system test — will need updating.
2. **`css_extract_ignore_order_warnings` becomes inert.** It configures the
   extraction plugin's `ignoreOrder`; built-in CSS emits no order-conflict
   warnings at all, so there is nothing to silence. Doctor warns if you have it
   set to `true` on the built-in path.
3. **CSS source maps follow `devtool`** rather than the loader's own
   `sourceMap: true`.

## Known gaps

These are the reasons built-in CSS is not the default yet.

- **Server-side rendering needs a deterministic `localIdentName`.** webpack's
  production default is `[fullhash]`, which differs between a `web` and a `node`
  build, so server-rendered class names will not match the client's. Shakapacker
  does not yet pin a deterministic template. If you do SSR (React on Rails), set
  one yourself on both configs before switching.
- **CSS minification still needs a separate plugin on webpack.** Recent webpack
  versions minify CSS through their default `optimization.minimizer`, but that
  entry only applies when the array is left untouched, and Shakapacker replaces
  it to configure Terser. So the built-in minifier never runs here, on either
  CSS path. Shakapacker picks up `css-minimizer-webpack-plugin` when it is
  installed — the same as on the loader chain, where it is also what does the
  work. Note that this plugin is itself deprecated in favor of
  [`minimizer-webpack-plugin`](https://github.com/webpack/minimizer-webpack-plugin#css);
  Shakapacker does not wire that one up yet, so using it means configuring
  `optimization.minimizer` in your own config. Rspack is unaffected: it minifies
  CSS with `LightningCssMinimizerRspackPlugin` either way.
- **Rspack has not reached parity with webpack.** See Rspack's
  [built-in CSS tracking issue](https://github.com/web-infra-dev/rspack/issues/14002).
  Open items include `@custom-media`/`@custom-selector`, function-valued
  `exportsConvention` and `localIdentName`, and the CSS SSR runtime. Shakapacker
  supports both bundlers with the same semantics, so the default cannot flip
  until these close.
- **`css-loader` escape hatches have no equivalent.** `getJSON`,
  `localIdentRegExp`, and the filter-callback forms of `url`/`import` are not
  implemented by the built-in parser. If you override the css-loader options in
  your own config — as [the v9 upgrade guide](./v9_upgrade.md) shows — that hook
  goes away with the loader.

## Roadmap

1. **Now.** Both paths supported. The loader chain stays the default; built-in
   CSS is available by uninstalling `css-loader`.
2. **Next.** A migration flag to select the path explicitly, with a stated
   removal version, once SSR class-name determinism and Rspack parity land.
3. **v11.** Built-in CSS becomes the default. The loader chain stays available
   for one more major version, then goes away.

## See also

- [webpack Native CSS guide](https://webpack.js.org/guides/native-css/)
- [Rspack `experiments.css` deprecation](https://rspack.rs/config/deprecated-options)
- [CSS Modules Export Mode](./css-modules-export-mode.md)
- [CSS Delivery In Development](./style_loader_vs_mini_css.md)
