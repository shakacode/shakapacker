# Customizing Babel Config

## Default Configuration
The default configuration of babel is done by using `package.json` to use the file within the `shakapacker` package.

```json
{
  "babel": {
    "presets": [
      "./node_modules/shakapacker/package/babel/preset.js"
    ]
  }
}
```

## Customizing the Babel Config
This example shows how you can create an object and apply _additional_ presets and plugins on top of the default.

### React Configuration
To use this example file,

```
yarn add react react-dom @babel/preset-react
yarn add --dev @pmmmwh/react-refresh-webpack-plugin react-refresh
```

```js
// babel.config.js
module.exports = function (api) {
  const defaultConfigFunc = require('shakapacker/package/babel/preset.js')
  const resultConfig = defaultConfigFunc(api)
  const isDevelopmentEnv = api.env('development')
  const isProductionEnv = api.env('production')
  const isTestEnv = api.env('test')

  const changesOnDefault = {
    presets: [
      [
        '@babel/preset-react',
        {
          development: isDevelopmentEnv || isTestEnv,
          useBuiltIns: true
        } 
      ]
    ].filter(Boolean),
    plugins: [
      isProductionEnv && ['babel-plugin-transform-react-remove-prop-types', 
        { 
          removeImport: true 
        }
      ],
      process.env.WEBPACK_SERVE && 'react-refresh/babel'
    ].filter(Boolean),
  }

  resultConfig.presets = [...resultConfig.presets, ...changesOnDefault.presets]
  resultConfig.plugins = [...resultConfig.plugins, ...changesOnDefault.plugins ]

  return resultConfig
}
```
