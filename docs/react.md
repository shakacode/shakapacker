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

This manual setup is best for very simple React usage. For anything beyond a basic mount point, use [React on Rails](https://github.com/shakacode/react_on_rails).

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

## Development Workflow

For this basic manual setup, start Rails and the dev server in separate terminals:

```shell
rails s
./bin/shakapacker-dev-server
```

For richer React development ergonomics and deeper Rails integration, use [React on Rails](https://github.com/shakacode/react_on_rails).

## A Basic Demo App

To verify the setup end to end:

1. Create a new Rails app and install Shakapacker.
2. Install `react` and `react-dom`.
3. Create a controller/view with a `<div id="root"></div>` mount point.
4. Add a React entry point in `app/javascript/packs/application.jsx`.
5. Start Rails plus `./bin/shakapacker-dev-server`.
6. Visit your page and confirm the React component renders.
