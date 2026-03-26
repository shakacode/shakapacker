# React Integration

These steps describe using React with Shakapacker in a Rails app.

## Easy Setup

If you'd like tighter Rails/React integration, see [React on Rails](https://github.com/shakacode/react_on_rails).

For React on Rails setups that rely on ExecJS, ensure Node is available:

```shell
EXECJS_RUNTIME=Node
```

## Basic Manual Setup

Create a new Rails app as per the [installation instructions in the README](https://github.com/shakacode/shakapacker#installation).

Install React:

```shell
npm install react react-dom
```

Shakapacker v9 defaults to SWC for webpack, and Rspack uses SWC natively, so `.jsx` and `.tsx`
entry points work out of the box. You only need extra JSX transpiler setup if you explicitly use
`javascript_transpiler: "babel"`.

If you use Babel, also install `@babel/preset-react` and follow the
[React Babel configuration example](./customizing_babel_config.md#react-configuration).

Create an entry point such as `app/javascript/packs/application.jsx`:

```jsx
import { createRoot } from "react-dom/client"
import App from "../App"

const container = document.getElementById("root")

if (container) {
  const root = createRoot(container)
  root.render(<App />)
}
```

Create the component in `app/javascript/App.jsx`:

```jsx
export default function App() {
  return <h1>Hello from React + Shakapacker</h1>
}
```

Render the mount point in your Rails view and include the pack:

```erb
<div id="root"></div>
<%= javascript_pack_tag "application" %>
```

## Enabling Hot Module Replacement (HMR)

Enable HMR in `config/shakapacker.yml`:

```yaml
development:
  dev_server:
    hmr: true
```

Install React Refresh and the plugin for your bundler:

```shell
# webpack
npm install --save-dev react-refresh @pmmmwh/react-refresh-webpack-plugin

# rspack
npm install --save-dev react-refresh @rspack/plugin-react-refresh
```

With the default Shakapacker development config, the correct React Refresh plugin is added
automatically when HMR is enabled and the package is installed. You do not need to manually push
the plugin into `config/webpack/webpack.config.js` or `config/rspack/rspack.config.js` unless you
have a custom setup.

If you use a custom Babel config, also add the `react-refresh/babel` plugin as shown in the
[React Babel configuration example](./customizing_babel_config.md#react-configuration).

Start Rails and the dev server in separate terminals:

```shell
rails s
./bin/shakapacker-dev-server
```

## A Basic Demo App

To verify the setup end to end:

1. Create a new Rails app and install Shakapacker.
2. Install `react` and `react-dom`.
3. Create a controller/view with a `<div id="root"></div>` mount point.
4. Add a React entry point in `app/javascript/packs/application.jsx`.
5. Start Rails plus `./bin/shakapacker-dev-server`.
6. Visit your page and confirm the React component renders.

When HMR is enabled, edits to normal React components should update in place. Editing the entry
file itself may still trigger a full reload; see
[react-refresh-webpack-plugin#177](https://github.com/pmmmwh/react-refresh-webpack-plugin/issues/177)
for background.
