// See the shakacode/shakapacker README and docs directory for advice on customizing your rspackConfig.
const { generateRspackConfig } = require('shakapacker/rspack')

const commonOptions = {
  resolve: {
    extensions: ['.css', '.ts', '.tsx']
  },
  ignoreWarnings: [/Module not found: Can't resolve 'react-dom\/client'/]
}

// rspack-manifest-plugin exports RspackManifestPlugin as an alias of its
// WebpackManifestPlugin class, so match manifest plugins by constructor-name
// suffix rather than enumerating each alias. The match is intentionally broad:
// any plugin whose constructor name ends in `ManifestPlugin` is stripped from
// the server config, not just the known aliases.
const shouldRemoveServerPlugin = (name) =>
  name === 'CssExtractRspackPlugin' || name.endsWith('ManifestPlugin')

const loaderName = (loader) => {
  if (typeof loader === 'string') {
    return loader
  }

  if (typeof loader?.loader === 'string') {
    return loader.loader
  }

  return ''
}

const configureUseForServer = (use) =>
  use
    .filter((item) => {
      const name = loaderName(item)

      return !(
        name.includes('mini-css-extract-plugin') ||
        name.includes('cssExtractLoader') ||
        name === 'style-loader'
      )
    })
    .map((item) => {
      if (
        typeof item === 'string' ||
        !loaderName(item).includes('css-loader') ||
        !item.options?.modules
      ) {
        return item
      }

      return {
        ...item,
        options: {
          ...item.options,
          modules: {
            ...item.options.modules,
            exportOnlyLocals: true
          }
        }
      }
    })

const configureRulesForServer = (rules) =>
  rules.map((rule) => {
    const configuredRule = { ...rule }

    if (Array.isArray(rule.oneOf)) {
      configuredRule.oneOf = configureRulesForServer(rule.oneOf)
    }

    // rule.use can also be a function (rspack/webpack supports this form);
    // function-based use rules are left unmodified — extend if such rules are added.
    if (Array.isArray(rule.use)) {
      configuredRule.use = configureUseForServer(rule.use)
    }

    return configuredRule
  })

const clientConfig = () => {
  const config = generateRspackConfig(commonOptions)

  delete config.entry['server-bundle']

  return config
}

const serverConfig = () => {
  const config = generateRspackConfig(commonOptions)
  const serverEntry = config.entry['server-bundle']

  if (!serverEntry) {
    console.warn(
      "[React on Rails] No 'server-bundle' pack found — skipping server bundle. " +
        "Create a pack named 'server-bundle.js' to enable server rendering."
    )
    return null
  }

  config.entry = { 'server-bundle': serverEntry }
  config.optimization = {
    minimize: false,
    splitChunks: false,
    runtimeChunk: false
  }
  config.output = {
    ...config.output,
    filename: 'server-bundle.js',
    globalObject: 'this'
  }
  // Filter by constructor name — works in dev/test where class names are preserved.
  // MUST NEVER run against a minified shakapacker bundle: production minification
  // mangles these class names to single letters and the filter would silently no-op.
  // Optional chaining + the '' fallback guard against null/raw-function/POJO plugins.
  config.plugins = config.plugins.filter(
    (plugin) => !shouldRemoveServerPlugin(plugin?.constructor?.name ?? '')
  )

  config.module.rules = configureRulesForServer(config.module.rules)

  // 'eval' is invalid under rspack's mode: 'production'; fall back to no source maps there.
  config.devtool = config.mode === 'production' ? false : 'eval'

  return config
}

module.exports = () => {
  if (process.env.WEBPACK_SERVE || process.env.CLIENT_BUNDLE_ONLY) {
    console.log('[React on Rails] Creating only the client bundles.')
    return clientConfig()
  }

  if (process.env.SERVER_BUNDLE_ONLY) {
    const server = serverConfig()
    if (!server) {
      throw new Error(
        "SERVER_BUNDLE_ONLY=1 set but no 'server-bundle' pack exists. " +
          "Create a pack named 'server-bundle.js' to enable server rendering."
      )
    }
    console.log('[React on Rails] Creating only the server bundle.')
    return server
  }

  const server = serverConfig()
  if (!server) {
    console.log(
      '[React on Rails] Creating only the client bundles (no server-bundle pack).'
    )
    return clientConfig()
  }

  console.log('[React on Rails] Creating both client and server bundles.')
  return [clientConfig(), server]
}
