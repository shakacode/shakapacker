// See the shakacode/shakapacker README and docs directory for advice on customizing your rspackConfig.
const { generateRspackConfig } = require('shakapacker/rspack')

const commonOptions = {
  resolve: {
    extensions: ['.css', '.ts', '.tsx']
  },
  ignoreWarnings: [/Module not found: Can't resolve 'react-dom\/client'/]
}

const constructorNamesToRemove = new Set([
  'WebpackManifestPlugin',
  'CssExtractRspackPlugin'
])

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
        name.match(/mini-css-extract-plugin/) ||
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
    throw new Error(
      "Create a pack with the file name 'server-bundle.js' containing all the server rendering files"
    )
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
  config.plugins = config.plugins.filter(
    (plugin) => !constructorNamesToRemove.has(plugin.constructor.name)
  )

  config.module.rules = configureRulesForServer(config.module.rules)

  config.devtool = 'eval'

  return config
}

module.exports = () => {
  if (process.env.WEBPACK_SERVE || process.env.CLIENT_BUNDLE_ONLY) {
    console.log('[React on Rails] Creating only the client bundles.')
    return clientConfig()
  }

  if (process.env.SERVER_BUNDLE_ONLY) {
    console.log('[React on Rails] Creating only the server bundle.')
    return serverConfig()
  }

  console.log('[React on Rails] Creating both client and server bundles.')
  return [clientConfig(), serverConfig()]
}
