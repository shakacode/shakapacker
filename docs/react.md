# React Integration

These steps describe how to create a Rails/React app, using Shakapacker as the bundler.

Before starting, ensure that you have Yarn installed, for example:

```shell
npm i -g yarn
```

## Basic Setup

Create a new Rails app as per the [installation instructions in the README](https://github.com/shakacode/shakapacker#installation).

Add React, as well as the necessary libraries to enable CSS support in your application:

```shell
yarn add react react-dom @babel/preset-react
yarn add css-loader style-loader mini-css-extract-plugin css-minimizer-webpack-plugin
```

Update the Babel configuration in the `package.json` file:

```diff
"babel": {
  "presets": [
    "./node_modules/shakapacker/package/babel/preset.js",
+   "@babel/preset-react"
  ]
},
```

And that's it. You can now create a React app using `app/javascript/application.js` as your entry point.

## Enabling Hot Module Replacement (HMR)

With HMR enabled, Shakapacker will automatically update only that part of the page that changed when it detects changes in your project files. This has the nice advantage of preserving your app’s state.

To enable HMR in a React app, proceed as follows:.

In `config/webpacker.yml` set `hmr` is set to `true`.

Install the [react-refresh](https://www.npmjs.com/package/react-refresh) package, as well as [@pmmmwh/react-refresh-webpack-plugin](https://www.npmjs.com/package/@pmmmwh/react-refresh-webpack-plugin):

```shell
yarn add --dev react-refresh @pmmmwh/react-refresh-webpack-plugin
```

Alter `config/webpack/webpack.config.js` like so:

```js
const { webpackConfig, inliningCss } = require('shakapacker');
const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');
const isDevelopment = process.env.NODE_ENV !== 'production';

if (isDevelopment && inliningCss) {
  webpackConfig.plugins.push(
    new ReactRefreshWebpackPlugin({
      overlay: {
        sockPort: webpackConfig.devServer.port,
      },
    })
  );
}

module.exports = webpackConfig;
```

This applies the plugin to the webpack configuration.

Delete the Babel configuration from `package.json`:

```diff
- "babel": {
-   "presets": [
-     "./node_modules/shakapacker/package/babel/preset.js",
-     "@babel/preset-react"
-   ]
- },
```

Then create a `babel.config.js` file in the root of project and add the following:

```js
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

This is taken from the [sample React Babel config](https://github.com/jameshibbard/shakapacker/blob/master/docs/customizing_babel_config.md#react-configuration).

HMR for your React app is now enabled. 🚀

## A Basic Demo App

To test that all of the above is working, you can follow these instructions to create a basic React app using Shakapacker.

1. Create a new Rails app:
```shell
rails new myapp --skip-javascript
cd myapp
bundle add shakapacker --strict
./bin/bundle install
./bin/rails webpacker:install
yarn add react react-dom @babel/preset-react
yarn add css-loader style-loader mini-css-extract-plugin css-minimizer-webpack-plugin
```

2. Generate a controller
```shell
rails g controller site index
echo '<div id="root"></div>' > app/views/site/index.html.erb
```

3. Create a CSS file and a React component:
```shell
touch app/javascript/App.css app/javascript/App.js
```

4. Edit `app/javascript/application.js` like so:
```jsx
import React from 'react';
import { createRoot } from 'react-dom/client';
import HelloMessage from './App';

const container = document.getElementById('root');
const root = createRoot(container);

document.addEventListener('DOMContentLoaded', () => {
  root.render(<HelloMessage name="World" />);
});
```

5. Add the following to `app/javascript/App.js`:
```jsx
import React from 'react';
import 'App.css';
const HelloMessage = ({ name }) => <h1>Hello, {name}!</h1>;
export default HelloMessage;
```

6. Add the following to `app/javascript/App.css`:
```css
h1 { color: blue; }
```

7. Enable HMR in config/webpacker.yml:
```shell
hmr: true
```

8. Install the [react-refresh](https://www.npmjs.com/package/react-refresh) package, as well as [@pmmmwh/react-refresh-webpack-plugin](https://www.npmjs.com/package/@pmmmwh/react-refresh-webpack-plugin):

```shell
yarn add --dev react-refresh @pmmmwh/react-refresh-webpack-plugin
```

9. Alter `config/webpack/webpack.config.js` like so:

```js
const { webpackConfig, inliningCss } = require('shakapacker');
const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');
const isDevelopment = process.env.NODE_ENV !== 'production';

if (isDevelopment && inliningCss) {
  webpackConfig.plugins.push(
    new ReactRefreshWebpackPlugin({
      overlay: {
        sockPort: webpackConfig.devServer.port,
      },
    })
  );
}

module.exports = webpackConfig;
```

10. Remove the Babel configuration from `package.json`
```diff
- "babel": {
-   "presets": [
-     "./node_modules/shakapacker/package/babel/preset.js"
-   ]
- },
```

11. Create a `babel.config.js` file in the project root and add the following [sample code](https://github.com/shakacode/shakapacker/blob/master/docs/customizing_babel_config.md#react-configuration):
```js
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

9. Start the Rails server and the webpack-dev-server in separate console windows:
```shell
rails s
./bin/webpacker-dev-server
```

10. Hit: <http://localhost:3000/site/index>

11. Edit either the React component at `app/javascript/App.js` or the CSS file at `app/javascript/App.css` and observe the HMR goodness.

Note that HMR will not work if you edit `app/javascript/application.js` and you experience a full refresh with a warning in the console. For more info on this, see here: https://github.com/pmmmwh/react-refresh-webpack-plugin/issues/177
