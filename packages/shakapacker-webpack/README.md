# shakapacker-webpack

`shakapacker-webpack` is the supplemental package for Shakapacker's managed webpack build path. It pairs `shakapacker` with the exact webpack, loader, and plugin versions that Shakapacker currently supports for the standard webpack setup.

## Install

```sh
npm install --save-dev shakapacker@^10.1.0 shakapacker-webpack@^10.1.0 webpack@5.106.2 webpack-cli@7.0.2 webpack-assets-manifest@6.5.1
```

Install the optional peers that match your app's configuration. For the default SWC path, install `@swc/core@1.15.33` and `swc-loader@0.2.7`. For dev-server/HMR usage, install `webpack-dev-server@5.2.3`; webpack-dev-server 4.x remains part of the legacy core compatibility window, not the supplemental package's managed stack.
