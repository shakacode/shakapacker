// The source code including full typescript support is available at: 
// https://github.com/shakacode/react_on_rails_demo_ssr_hmr/blob/master/config/webpack/development.js

const { devServer, inliningCss, config } = require('shakapacker');

const generateWebpackConfigs = require('./generateWebpackConfigs');

const developmentEnvOnly = (clientWebpackConfig, _serverWebpackConfig) => {
  // React Refresh (Fast Refresh) setup - only when webpack-dev-server is running (HMR mode)
  // This matches the condition in generateWebpackConfigs.js and babel.config.js
  if (process.env.WEBPACK_SERVE) {
    if (config.assets_bundler === 'rspack') {
      // eslint-disable-next-line global-require
      const ReactRefreshPlugin = require('@rspack/plugin-react-refresh');
      clientWebpackConfig.plugins.push(new ReactRefreshPlugin());
    } else {
      // eslint-disable-next-line global-require
      const ReactRefreshWebpackPlugin = require('@pmmmwh/react-refresh-webpack-plugin');
      clientWebpackConfig.plugins.push(
        new ReactRefreshWebpackPlugin({
          // Use default overlay configuration for better compatibility
        }),
      );
    }
  }
};

module.exports = generateWebpackConfigs(developmentEnvOnly);
