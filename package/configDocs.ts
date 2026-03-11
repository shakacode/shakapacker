// Shared configuration documentation for webpack/rspack keys
// Used by both configDiffer (contextual docs) and configExporter (inline annotations)

export interface ConfigDoc {
  description: string
  defaultValue?: string
  affects?: string
  documentationUrl?: string
}

const WEBPACK_CONFIG_DOCS: Record<string, ConfigDoc> = {
  mode: {
    description:
      "Controls webpack optimization: 'development' (fast builds, detailed errors), " +
      "'production' (optimized, minified), or 'none'.",
    affects:
      "Minification, tree-shaking, source maps, and performance optimizations",
    documentationUrl: "https://webpack.js.org/configuration/mode/"
  },
  devtool: {
    description:
      "Source map style: 'source-map' (full, slow), 'eval-source-map' (full, fast rebuild), " +
      "'cheap-source-map' (fast, less detail), false (none).",
    affects: "Build speed, debugging experience, and bundle size",
    documentationUrl: "https://webpack.js.org/configuration/devtool/"
  },
  output: {
    description: "Configuration for output bundles.",
    documentationUrl: "https://webpack.js.org/configuration/output/"
  },
  "output.path": {
    description: "Absolute directory path where bundles are written.",
    affects: "Where webpack writes compiled files",
    documentationUrl: "https://webpack.js.org/configuration/output/#outputpath"
  },
  "output.publicPath": {
    description:
      "URL prefix for loading assets in the browser (used by webpack for code splitting and asset loading).",
    affects: "Asset URLs in generated HTML and runtime chunk loading",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputpublicpath"
  },
  "output.filename": {
    description:
      "Bundle name template. [name]=entry name, [contenthash]=content-based hash for caching, " +
      "[chunkhash]=chunk hash.",
    affects: "Output filenames and cache busting strategy",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputfilename"
  },
  "output.chunkFilename": {
    description:
      "Template for non-entry chunk files created by code splitting.",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputchunkfilename"
  },
  "output.assetModuleFilename": {
    description: "Template for asset module filenames (images, fonts, etc.).",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputassetmodulefilename"
  },
  "output.crossOriginLoading": {
    description:
      "Cross-origin loading setting for script tags: 'anonymous', 'use-credentials', or false.",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputcrossoriginloading"
  },
  "output.globalObject": {
    description:
      "Global object reference for UMD builds (e.g., 'this', 'window', 'global').",
    documentationUrl:
      "https://webpack.js.org/configuration/output/#outputglobalobject"
  },
  optimization: {
    description: "Code optimization settings.",
    documentationUrl: "https://webpack.js.org/configuration/optimization/"
  },
  "optimization.minimize": {
    description: "Enable/disable minification of JavaScript bundles.",
    defaultValue: "true in production, false in development",
    affects: "Bundle size and build time",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationminimize"
  },
  "optimization.minimizer": {
    description:
      "Array of minimizer plugins (e.g., TerserPlugin, CssMinimizerPlugin).",
    defaultValue: "TerserPlugin for JS",
    affects: "Minification strategy and bundle size",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationminimizer"
  },
  "optimization.splitChunks": {
    description:
      "Code splitting configuration - extracts common dependencies into separate chunks.",
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
  "optimization.runtimeChunk": {
    description:
      "Extract webpack runtime into separate chunk: 'single' (one runtime for all), " +
      "true (one per entry), false (inline).",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationruntimechunk"
  },
  "optimization.moduleIds": {
    description:
      "Module ID generation strategy: 'deterministic' (stable), 'named' (readable), " +
      "'natural' (numeric order).",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationmoduleids"
  },
  "optimization.chunkIds": {
    description:
      "Chunk ID generation strategy: 'deterministic', 'named', 'natural'.",
    documentationUrl:
      "https://webpack.js.org/configuration/optimization/#optimizationchunkids"
  },
  "cache.type": {
    description:
      "Type of caching: 'memory' (in-memory) or 'filesystem' (persistent disk cache).",
    affects: "Build speed on subsequent builds",
    documentationUrl: "https://webpack.js.org/configuration/cache/#cachetype"
  },
  cache: {
    description:
      "Build caching configuration: false (disabled), { type: 'memory' }, or { type: 'filesystem' }.",
    documentationUrl: "https://webpack.js.org/configuration/cache/"
  },
  module: {
    description: "Configures how different file types are processed.",
    affects: "How different file types are processed",
    documentationUrl: "https://webpack.js.org/configuration/module/"
  },
  "module.rules": {
    description:
      "Array of rules defining loaders and processing for different file types.",
    affects: "How files (JS, CSS, images, etc.) are transformed",
    documentationUrl: "https://webpack.js.org/configuration/module/#modulerules"
  },
  plugins: {
    description:
      "Array of webpack plugins to apply (e.g., HtmlWebpackPlugin, MiniCssExtractPlugin).",
    affects: "Build process, output, and optimizations",
    documentationUrl: "https://webpack.js.org/configuration/plugins/"
  },
  resolve: {
    description: "Module resolution configuration.",
    affects: "How imports are resolved",
    documentationUrl: "https://webpack.js.org/configuration/resolve/"
  },
  "resolve.extensions": {
    description:
      "File extensions to try when resolving modules (e.g., ['.js', '.jsx', '.ts', '.tsx']).",
    defaultValue: "['.js', '.json', '.wasm']",
    affects: "Which files can be imported without extensions",
    documentationUrl:
      "https://webpack.js.org/configuration/resolve/#resolveextensions"
  },
  "resolve.modules": {
    description:
      "Directories to search when resolving modules (e.g., ['node_modules', 'app/javascript']).",
    documentationUrl:
      "https://webpack.js.org/configuration/resolve/#resolvemodules"
  },
  "resolve.alias": {
    description:
      "Create import aliases for modules (e.g., @components -> ./src/components).",
    documentationUrl:
      "https://webpack.js.org/configuration/resolve/#resolvealias"
  },
  resolveLoader: {
    description: "Configuration for resolving loaders.",
    documentationUrl: "https://webpack.js.org/configuration/resolve-loader/"
  },
  "resolveLoader.modules": {
    description: "Directories to search for loaders.",
    documentationUrl:
      "https://webpack.js.org/configuration/resolve-loader/#resolveloadermodules"
  },
  entry: {
    description:
      "Entry points for the application - where webpack starts building the dependency graph.",
    affects: "What code is included in the bundle",
    documentationUrl:
      "https://webpack.js.org/configuration/entry-context/#entry"
  },
  target: {
    description:
      "Build target environment: 'web' (browser), 'node' (Node.js), 'webworker', etc.",
    defaultValue: "'web'",
    affects: "Which environment-specific features are enabled",
    documentationUrl: "https://webpack.js.org/configuration/target/"
  },
  externals: {
    description:
      "Dependencies to exclude from bundle (assumed to be available in runtime environment).",
    affects: "Bundle size and runtime dependencies",
    documentationUrl: "https://webpack.js.org/configuration/externals/"
  },
  performance: {
    description: "Performance budget configuration.",
    defaultValue: "Warnings at 250kb",
    affects: "Build warnings about bundle size",
    documentationUrl: "https://webpack.js.org/configuration/performance/"
  },
  "performance.maxAssetSize": {
    description:
      "Maximum size (in bytes) for individual assets before webpack warns.",
    documentationUrl:
      "https://webpack.js.org/configuration/performance/#performancemaxassetsize"
  },
  "performance.maxEntrypointSize": {
    description:
      "Maximum size (in bytes) for entry point bundles before webpack warns.",
    documentationUrl:
      "https://webpack.js.org/configuration/performance/#performancemaxentrypointsize"
  },
  devServer: {
    description:
      "Webpack dev server configuration (HMR, proxying, HTTPS, etc.).",
    documentationUrl: "https://webpack.js.org/configuration/dev-server/"
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
    description: "Port number for dev server.",
    defaultValue: "8080",
    affects: "URL where dev server is accessible",
    documentationUrl:
      "https://webpack.js.org/configuration/dev-server/#devserverport"
  },
  "devServer.host": {
    description: "Host for dev server (e.g., 'localhost', '0.0.0.0').",
    documentationUrl:
      "https://webpack.js.org/configuration/dev-server/#devserverhost"
  },
  "devServer.https": {
    description: "Enable HTTPS for dev server.",
    documentationUrl:
      "https://webpack.js.org/configuration/dev-server/#devserverhttps"
  },
  stats: {
    description:
      "Controls bundle information display: 'normal', 'verbose', 'minimal', 'errors-only', 'none'.",
    documentationUrl: "https://webpack.js.org/configuration/stats/"
  },
  bail: {
    description:
      "Fail the build on first error (true) or continue and report all errors (false).",
    documentationUrl: "https://webpack.js.org/configuration/other-options/#bail"
  },
  watch: {
    description: "Enable watch mode - rebuild on file changes.",
    documentationUrl: "https://webpack.js.org/configuration/watch/"
  },
  watchOptions: {
    description: "Watch mode configuration (polling, ignored files, etc.).",
    documentationUrl: "https://webpack.js.org/configuration/watch/#watchoptions"
  }
}

export function getDocForKey(keyPath: string): ConfigDoc | undefined {
  return WEBPACK_CONFIG_DOCS[keyPath]
}

export function getDocDescription(keyPath: string): string | undefined {
  return WEBPACK_CONFIG_DOCS[keyPath]?.description
}

export function getDocDescriptionWithFallback(
  keyPath: string
): string | undefined {
  if (WEBPACK_CONFIG_DOCS[keyPath]) {
    return WEBPACK_CONFIG_DOCS[keyPath].description
  }

  const parts = keyPath.split(".")
  if (parts.length > 1) {
    const parentKey = parts.slice(0, -1).join(".")
    return WEBPACK_CONFIG_DOCS[parentKey]?.description
  }

  return undefined
}
