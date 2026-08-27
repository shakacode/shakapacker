# Using SWC Loader

SWC is the recommended JavaScript transpiler in Shakapacker v10 (this default was introduced in v9), and is set as the default in new installations. If you face any issues, please report them at [Shakapacker Issues](https://github.com/shakacode/shakapacker/issues).

## About SWC

[SWC (Speedy Web compiler)](https://swc.rs/) is a Rust-based compilation and bundler tool that can be used for Javascript and Typescript files. SWC's own benchmark reports being [20x faster than Babel on a single thread and 70x faster on four cores](https://swc.rs/); end-to-end Shakapacker build wins are typically smaller than that pure-transpiler number but still substantial.

It supports all ECMAScript features and it's designed to be a drop-in replacement for Babel and its plugins. Out of the box, it supports TS, JSX syntax, React fast refresh, and much more.

For comparison between SWC and Babel, see the docs at https://swc.rs/docs/migrating-from-babel.

> **Note:** SWC is also natively built into RSpack bundler, providing even faster compilation speeds. When using RSpack (`assets_bundler: 'rspack'`), SWC is the default if `javascript_transpiler` is not explicitly set.

## Using SWC in your Shakapacker project

For new installations of Shakapacker v9+, SWC is automatically configured in the installation template.

**Note**: While the installation template sets SWC as the default, webpack's runtime fallback (when no explicit config exists) remains Babel for backward compatibility. Rspack always defaults to SWC.

If you're upgrading from v8 or earlier and want to switch from Babel to SWC:

1. Make sure you've installed `@swc/core` and `swc-loader` packages.

```bash
npm install @swc/core swc-loader
```

2. Confirm `javascript_transpiler` is set to `swc` in your `config/shakapacker.yml`:

```yml
default: &default
  source_path: app/javascript
  source_entry_path: /
  public_root_path: public
  public_output_path: packs
  cache_path: tmp/shakapacker
  webpack_compile_output: true

  # Additional paths webpack should look up modules
  # ['app/assets', 'engine/foo/app/assets']
  additional_paths: []

  # Reload manifest.json on all requests so we reload latest compiled packs
  cache_manifest: false

  # Select JavaScript transpiler to use
  # Available options: 'swc' (default, ~20x faster than Babel per swc.rs), 'babel', or 'esbuild'
  # Note: When using rspack, swc is used automatically regardless of this setting
  javascript_transpiler: "swc"
```

## Usage

### React

React is supported out of the box, provided you use `.jsx` or `.tsx` file extension. Shakapacker config will correctly recognize those and tell SWC to parse the JSX syntax correctly. If you wish to customize the transform options to match any existing `@babel/preset-react` settings, you can do that through customizing loader options as described below. You can see available options at https://swc.rs/docs/configuration/compilation#jsctransformreact.

### Typescript

Typescript is supported out of the box, but certain features like decorators need to be enabled through the custom config. You can see available customizations options at https://swc.rs/docs/configuration/compilation, which you can apply through customizing loader options as described below.

Please note that SWC is not using the settings from `.tsconfig` file. Any non-default settings you might have there will need to be applied to the custom loader config.

## Customizing loader options

You can see the default loader options at [swc/index.js](../package/swc/index.js).

If you wish to customize the loader defaults further, for example, if you want to enable support for decorators or React fast refresh, you need to create a `swc.config.js` file in your app config folder.

This file should have a single default export which is an object with an `options` key. Your customizations will be merged with default loader options. You can use this to override or add additional configurations.

Inside the `options` key, you can use any options available to the SWC compiler. For the options reference, please refer to [official SWC docs](https://swc.rs/docs/configuration/compilation).

See some examples below of potential `config/swc.config.js`.

### Example: Enabling top level await and decorators

```js
const customConfig = {
  options: {
    jsc: {
      parser: {
        topLevelAwait: true,
        decorators: true
      }
    }
  }
}

module.exports = customConfig
```

### Example: Matching existing `@babel/present-env` config

```js
const { env } = require("shakapacker")

const customConfig = {
  options: {
    jsc: {
      transform: {
        react: {
          development: env.isDevelopment,
          useBuiltins: true
        }
      }
    }
  }
}

module.exports = customConfig
```

### Example: Enabling React Fast Refresh

:warning: Shakapacker's default development config automatically adds [@pmmmwh/react-refresh-webpack-plugin](https://github.com/pmmmwh/react-refresh-webpack-plugin) when HMR is enabled and the package is installed. Use the setting below when you need to customize the SWC React transform itself; it replaces the equivalent `react-refresh/babel` Babel plugin behavior.

```js
const { env } = require("shakapacker")

const customConfig = {
  options: {
    jsc: {
      transform: {
        react: {
          refresh: env.isDevelopment && env.runningWebpackDevServer
        }
      }
    }
  }
}

module.exports = customConfig
```

### Example: Adding browserslist config

```js
const customConfig = {
  options: {
    env: {
      targets: "> 0.25%, not dead"
    }
  }
}

module.exports = customConfig
```

## Using SWC with Stimulus

⚠️ **Important:** If you're using [Stimulus](https://stimulus.hotwired.dev/), you need to configure SWC to preserve class names.

### Required Configuration

SWC mangles (minifies) class names by default for optimization. Since Stimulus relies on class names to discover and instantiate controllers, you must preserve class names in your `config/swc.config.js`:

```js
// config/swc.config.js
const { env } = require("shakapacker")

module.exports = {
  options: {
    jsc: {
      // CRITICAL for Stimulus: Prevents SWC from mangling class names
      keepClassNames: true,
      transform: {
        react: {
          runtime: "automatic",
          refresh: env.isDevelopment && env.runningWebpackDevServer
        }
      }
    }
  }
}
```

**Note:** Starting with Shakapacker v9.1.0, the default `swc.config.js` created by `rake shakapacker:migrate_to_swc` includes `keepClassNames: true` automatically.

### Why This Matters

Without `keepClassNames: true`, your Stimulus controllers will:

- Load without errors in the browser console
- Fail silently at runtime
- Not respond to events
- Not update the DOM as expected

This makes debugging very difficult since there are no visible JavaScript errors.

### Symptoms of Missing Configuration

If your Stimulus controllers aren't working after migrating to SWC, you'll typically see test failures like:

```
Failure/Error: expect(page).to have_text("Author: can't be blank")
  expected to be truthy, got false

Failure/Error: expect(page).to have_css("h2", text: comment.author)
  expected to be truthy, got false
```

Your controllers appear to load but don't function correctly:

- Form submissions don't work
- Validation error messages don't appear
- Dynamic content doesn't get added to the page
- No JavaScript errors appear in the console

### Common Configuration Error

❌ **Error:** `` `env` and `jsc.target` cannot be used together``

If you see this error:

```
ERROR in ./client/app/packs/stimulus-bundle.js
Module build failed (from ./node_modules/swc-loader/src/index.js):
Error:

Caused by:
    `env` and `jsc.target` cannot be used together
```

**Solution:** Do NOT add `jsc.target` to your configuration. Shakapacker already sets `env` for browser targeting. Use `env` OR `jsc.target`, never both.

❌ **Incorrect:**

```js
jsc: {
  target: 'es2015',  // Don't add this!
  keepClassNames: true,
}
```

✅ **Correct:**

```js
jsc: {
  keepClassNames: true,  // No target specified
}
```

### Troubleshooting Checklist

If your Stimulus controllers aren't working after migrating to SWC:

1. ✅ Verify `keepClassNames: true` is set in `config/swc.config.js`
2. ✅ Ensure your controllers have explicit class names (not anonymous classes)
3. ✅ Test with `console.log()` in your controller's `connect()` method to verify it's being instantiated
4. ✅ Check that you haven't added `jsc.target` (which conflicts with Shakapacker's `env` setting)
5. ✅ Rebuild your assets: `bundle exec rake shakapacker:clobber && bundle exec rake shakapacker:compile`

## Wasm plugin compatibility with Rspack

If you use `jsc.experimental.plugins` to load a Wasm SWC plugin (for example `@swc/plugin-styled-components` or `swc-plugin-coverage-instrument`), the plugin build must match the exact `swc_core` version that your installed bundler depends on. Per [SWC's own docs](https://swc.rs/docs/plugin/selecting-swc-core), "the Wasm plugins are not backwards compatible" — this is **not** a minimum-version floor, it's an exact/closely-tied version pairing: a plugin built against a _higher_ `swc_core` than your bundler embeds fails too, not just a lower one. This applies to Rspack's `builtin:swc-loader` (Rspack's own SWC integration) just as much as to `swc-loader` on webpack.

**Where you configure this differs by bundler.** On webpack, `jsc.experimental.plugins` goes in `config/swc.config.js` like any other option in [Customizing loader options](#customizing-loader-options) above — Shakapacker's webpack SWC rule reads that file and merges it in. On Rspack, it does not: Shakapacker's built-in Rspack rule hard-codes its `builtin:swc-loader` options inline and never reads `config/swc.config.js`. A Wasm plugin placed only in `config/swc.config.js` is silently ignored on the Rspack path — no error, it just never loads. If you're on Rspack and need `jsc.experimental.plugins`, add it yourself by overriding the JS/TS loader rule in your own `config/rspack/rspack.config.js`; that's also where the fix below applies.

**Rspack 2.2 upgraded `swc_core` from 76 to 77.** If you're on `assets_bundler: 'rspack'` and upgrade to Rspack 2.2 while keeping a Wasm plugin that isn't built specifically for `swc_core` 77, your build fails with:

```text
The version of the SWC Wasm plugin you're using might not be compatible with 'builtin:swc-loader'
```

**Fix:**

- Get or rebuild a plugin build that specifically targets the `swc_core` version your installed Rspack release embeds (77, for Rspack 2.2 — this mapping is specific to the 2.2 release; a later Rspack release may bump `swc_core` again to yet another version, so don't assume 77 stays correct going forward). Check [plugins.swc.rs](https://plugins.swc.rs/) and select your Rspack version to find the matching plugin build, or
- Pin your Rspack packages (`@rspack/core`, `@rspack/cli`, etc.) to `< 2.2.0` until a compatible plugin build is available.

See Rspack's [SWC plugin version mismatch](https://rspack.rs/errors/swc-plugin-version) error reference for more detail, and the [Troubleshooting guide](./troubleshooting.md#swc-wasm-plugin-incompatible-with-rspacks-builtinswc-loader) for the same guidance in context.

## Known limitations

- `browserslist` config at the moment is not being picked up automatically. [Related SWC issue](https://github.com/swc-project/swc/issues/3365). You can add your browserlist config through customizing loader options as outlined above.
- Using `.swcrc` config file is currently not supported. You might face some issues when `.swcrc` config is diverging from the SWC options we're passing in the Webpack rule.
