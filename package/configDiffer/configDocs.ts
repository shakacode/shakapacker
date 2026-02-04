// Configuration documentation for webpack/rspack keys
// This provides contextual information about what each configuration key means

interface ConfigDoc {
  description: string
  defaultValue?: string
  affects?: string
  documentationUrl?: string
}

const WEBPACK_CONFIG_DOCS: Record<string, ConfigDoc> = {
  mode: {
    description:
      "Defines the environment mode (development, production, or none). " +
      "Controls built-in optimizations and defaults.",
    affects:
      "Minification, tree-shaking, source maps, and performance optimizations",
    documentationUrl: "https://webpack.js.org/configuration/mode/"
  },
  devtool: {
    description:
      "Controls how source maps are generated for debugging. " +
      "Different values trade off between build speed and debugging quality.",
    affects: "Build speed, debugging experience, and bundle size",
    documentationUrl: "https://webpack.js.org/configuration/devtool/"
  },
  "output.path": {
    description: "The output directory for compiled bundles (absolute path).",
    affects: "Where webpack writes compiled files",
    documentationUrl: "https://webpack.js.org/configuration/output/#outputpath"
  },
  "output.publicPath": {
    description: "The public URL path where bundles are served from.",
    affects: "Asset URLs in generated HTML and runtime chunk loading",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputpublicpath"
  },
  "output.filename": {
    description:
      "Filename template for entry chunks. Can include [name], [hash], [contenthash].",
    affects: "Output filenames and cache busting strategy",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputfilename"
  },
  "optimization.minimize": {
    description: "Enable/disable minification of JavaScript bundles.",
    defaultValue: "true in production, false in development",
    affects: "Bundle size and build time",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationminimize"
  },
  "optimization.minimizer": {
    description: "Array of plugins to use for minification.",
    defaultValue: "TerserPlugin for JS",
    affects: "Minification strategy and bundle size",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationminimizer"
  },
  "optimization.splitChunks": {
    description:
      "Code splitting configuration. Controls how chunks are split into separate files.",
    affects: "Bundle splitting, caching, and load performance",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationsplitchunks"
  },
  "optimization.splitChunks.chunks": {
    description:
      "Which chunks to optimize: 'all', 'async', or 'initial'. " +
      "'all' enables splitting for all chunk types.",
    defaultValue: "'async'",
    affects: "Which chunks are eligible for code splitting",
    documentationUrl:
      "https://webpack.js.org/plugins/split-chunks-plugin/#splitchunkschunks"
  },
  "optimization.splitChunks.maxSize": {
    description:
      "Maximum size (in bytes) for a chunk. Webpack will try to split chunks larger than this.",
    affects: "Number and size of output chunks",
    documentationUrl:
      "https://webpack.js.org/plugins/split-chunks-plugin/#splitchunksmaxsize"
  },
  "cache.type": {
    description:
      "Type of caching: 'memory' (in-memory) or 'filesystem' (persistent disk cache).",
    affects: "Build speed on subsequent builds",
    documentationUrl: "https://webpack.js.org/configuration/cache/#cachetype"
  },
  "devServer.hot": {
    description:
      "Enable Hot Module Replacement (HMR) for live updates without full reload.",
    defaultValue: "true",
    affects: "Development experience and reload behavior",
    documentationUrl:
      "https://webpack.js.org/configuration/dev-server/#devserverhot"
  },
  "devServer.port": {
    description: "Port number for the webpack dev server.",
    defaultValue: "8080",
    affects: "URL where dev server is accessible",
    documentationUrl:
      "https://webpack.js.org/configuration/dev-server/#devserverport"
  },
  target: {
    description:
      "Deployment target environment: 'web', 'node', 'electron-main', etc.",
    defaultValue: "'web'",
    affects: "Which environment-specific features are enabled",
    documentationUrl: "https://webpack.js.org/configuration/target/"
  },
  entry: {
    description:
      "Entry point(s) for the application. Where webpack starts building the dependency graph.",
    affects: "What code is included in the bundle",
    documentationUrl:
      "https://webpack.js.org/configuration/entry-context/#entry"
  },
  resolve: {
    description: "Options for module resolution (how webpack finds modules).",
    affects: "How imports are resolved",
    documentationUrl: "https://webpack.js.org/configuration/resolve/"
  },
  "resolve.extensions": {
    description:
      "File extensions to try when resolving modules (e.g., ['.js', '.jsx']).",
    defaultValue: "['.js', '.json', '.wasm']",
    affects: "Which files can be imported without extensions",
    documentationUrl:
      "https://webpack.js.org/configuration/resolve/#resolveextensions"
  },
  module: {
    description: "Options for module processing (loaders and rules).",
    affects: "How different file types are processed",
    documentationUrl: "https://webpack.js.org/configuration/module/"
  },
  "module.rules": {
    description:
      "Array of rules for processing different file types with loaders.",
    affects: "How files (JS, CSS, images, etc.) are transformed",
    documentationUrl: "https://webpack.js.org/configuration/module/#modulerules"
  },
  plugins: {
    description:
      "Array of plugins to extend webpack functionality (HTML generation, env vars, compression, etc.).",
    affects: "Build process, output, and optimizations",
    documentationUrl: "https://webpack.js.org/configuration/plugins/"
  },
  externals: {
    description:
      "Dependencies to exclude from bundles (assumed to be available at runtime).",
    affects: "Bundle size and runtime dependencies",
    documentationUrl: "https://webpack.js.org/configuration/externals/"
  },
  performance: {
    description: "Performance hints and warnings for bundle sizes.",
    defaultValue: "Warnings at 250kb",
    affects: "Build warnings about bundle size",
    documentationUrl: "https://webpack.js.org/configuration/performance/"
  }
}

export function getDocForKey(keyPath: string): ConfigDoc | undefined {
  return WEBPACK_CONFIG_DOCS[keyPath]
}

export function hasDocumentation(keyPath: string): boolean {
  return keyPath in WEBPACK_CONFIG_DOCS
}
