# Using SWC Loader

:warning: This feature is currently experimental. The configuration and API are subject to change during the beta release cycle.

If you face any issues, please report at https://github.com/shakacode/shakapacker/issues.

## About SWC

[SWC (Speedy Web compiler)](https://swc.rs/) is a Rust-based compilation and bundler tool that can be used for Javascript and Typescript files. It claims to be 20x faster than Babel!

It supports all ECMAScript features and it's designed to be a drop-in replacement for Babel and its plugins. Out of the box, it supports TS, JSX syntax, React fast refresh, and much more.

For comparison between SWC and Babel, see the docs at https://swc.rs/docs/migrating-from-babel.

## Switching your Shakapacker project to SWC

In order to use SWC as your compiler today. You need to do two things:

1. Make sure you've installed `@swc/core` and `swc-loader` packages.

```
yarn add @swc/core swc-loader
```

2. Add or change `webpack_loader` value in your default `webpacker.yml` config to `swc`
The default configuration of babel is done by using `package.json` to use the file within the `shakapacker` package.

```yml
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
const { env } = require('shakapacker')

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

:warning: Remember that you still need to add [@pmmmwh/react-refresh-webpack-plugin](https://github.com/pmmmwh/react-refresh-webpack-plugin) to your webpack config. The setting below just replaces equivalent `react-refresh/babel` Babel plugin.


```js
const { env } = require('shakapacker')

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
      targets: '> 0.25%, not dead'
    }
  }
}

module.exports = customConfig
```


## Known limitations

- `browserslist` config at the moment is not being picked up automatically. [Related SWC issue](https://github.com/swc-project/swc/issues/3365). You can add your browserlist config through customizing loader options as outlined above.
- Using `.swcrc` config file is currently not supported. You might face some issues when `.swcrc` config is diverging from the SWC options we're passing in the Webpack rule.
