# Customizing Babel Config

## Default Configuration

The default configuration of babel is done by using `package.json` to use the file within the `shakapacker` package.

```json
{
  "babel": {
    "presets": ["./node_modules/shakapacker/package/babel/preset.js"]
  }
}
```

## Customizing the Babel Config

### Basic Configuration

This is a very basic skeleton that you can use that includes the Shakapacker preset, and makes it easy to add new plugins and presents:

```js
// babel.config.js
module.exports = function (api) {
  const defaultConfigFunc = require("shakapacker/package/babel/preset.js")
  const resultConfig = defaultConfigFunc(api)

  const changesOnDefault = {
    presets: [
      // put custom presets here
    ].filter(Boolean),
    plugins: [
      // put custom plugins here
    ].filter(Boolean)
  }

  resultConfig.presets = [...resultConfig.presets, ...changesOnDefault.presets]
  resultConfig.plugins = [...resultConfig.plugins, ...changesOnDefault.plugins]

  return resultConfig
}
```

### React Configuration

This shows how you can add to the above skeleton to support React - to use this, install the following dependencies:

```bash
npm install react react-dom @babel/preset-react
npm install --dev @pmmmwh/react-refresh-webpack-plugin react-refresh
```

And then update the configuration:

```js
// babel.config.js
module.exports = function (api) {
  const defaultConfigFunc = require("shakapacker/package/babel/preset.js")
  const resultConfig = defaultConfigFunc(api)
  const isDevelopmentEnv = api.env("development")
  const isProductionEnv = api.env("production")
  const isTestEnv = api.env("test")

  const changesOnDefault = {
    presets: [
      [
        "@babel/preset-react",
        {
          development: isDevelopmentEnv || isTestEnv
        }
      ]
    ].filter(Boolean),
    plugins: [
      isProductionEnv && [
        "babel-plugin-transform-react-remove-prop-types",
        {
          removeImport: true
        }
      ],
      process.env.WEBPACK_SERVE && "react-refresh/babel"
    ].filter(Boolean)
  }

  resultConfig.presets = [...resultConfig.presets, ...changesOnDefault.presets]
  resultConfig.plugins = [...resultConfig.plugins, ...changesOnDefault.plugins]

  return resultConfig
}
```

### Babel 8

Shakapacker supports Babel 7 and Babel 8. If you use Babel 8, install matching
Babel 8 packages for the Shakapacker preset and use `babel-loader` 10 or newer:

```bash
npm install --save-dev @babel/core@^8 @babel/plugin-transform-runtime@^8 @babel/preset-env@^8 @babel/runtime@^8 babel-loader@^10
```

Babel 8 requires Node `^22.18.0 || >=24.11.0` while running the build. It also
removed some Babel 7 configuration options. The Shakapacker preset omits those
removed options when Babel 8 is running, but app-level custom Babel config should
also avoid Babel 7-only options such as `useBuiltIns` on `@babel/preset-react`
or `helpers` on `@babel/plugin-transform-runtime`.

Shakapacker validates the loader/core pairing when `javascript_transpiler:
"babel"` is active. If your app installs Babel 8, install `babel-loader` 10 or
newer; older `babel-loader` majors are only supported with Babel 7.

If your app relied on Babel 7 `@babel/preset-env` `useBuiltIns: "entry"`
polyfill rewriting, move polyfill injection to your app config for Babel 8, for
example with `babel-plugin-polyfill-corejs3`, or keep explicit `core-js` imports
that match your browser support policy.
