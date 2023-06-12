const isArray = (value) => Array.isArray(value)
const isBoolean = (str) => /^true/.test(str) || /^false/.test(str)
const chdirTestApp = () => {
  try {
    return process.chdir('spec/shakapacker/test_app')
  } catch (e) {
    return null
  }
}

// For backward compatibility
const chdirWebpackerTestApp = () => {
  try {
    return process.chdir('spec/backward_compatibility_specs/webpacker_test_app')
  } catch (e) {
    return null
  }
}

const chdirCwd = () => process.chdir(process.cwd())

const resetEnv = () => {
  process.env = {}
}

const ensureTrailingSlash = (path) => (path.endsWith('/') ? path : `${path}/`)

const resolvedPath = (packageName) => {
  try {
    return require.resolve(packageName)
  } catch (e) {
    if (e.code !== 'MODULE_NOT_FOUND') {
      throw e
    }
    return null
  }
}

const moduleExists = (packageName) => !!resolvedPath(packageName)

const canProcess = (rule, fn) => {
  const modulePath = resolvedPath(rule)

  if (modulePath) {
    return fn(modulePath)
  }

  return null
}

const loaderMatches = (configLoader, loaderToCheck, fn) => {
  if (configLoader !== loaderToCheck) {
    return null
  }

  const loaderName = `${configLoader}-loader`

  if (!moduleExists(loaderName)) {
    throw new Error(
      `Your Shakapacker config specified using ${configLoader}, but ${loaderName} package is not installed. Please install ${loaderName} first.`
    )
  }

  return fn()
}

// For backward compatibility
// Set SHAKAPACKER_XYZ only if SHAKAPACKER_XYZ is not defined but WEBPACKER_XYZ is.
const setShakapackerEnvVariablesForBackwardCompatibility = () => {
  const webpackerEnvVariables = Object.entries(process.env).filter((key) => /^WEBPACKER_/.test(key))
  webpackerEnvVariables.forEach(([webpackerEnvKey, webpackerEnvValue]) => {
    const shakapackerKey = webpackerEnvKey.replace(/^WEBPACKER/, 'SHAKAPACKER')
    if (!process.env[shakapackerKey]) {
      process.env[shakapackerKey] = webpackerEnvValue
    }
  })
}

module.exports = {
  chdirTestApp,
  chdirWebpackerTestApp,
  setShakapackerEnvVariablesForBackwardCompatibility,
  chdirCwd,
  isArray,
  isBoolean,
  ensureTrailingSlash,
  canProcess,
  moduleExists,
  resetEnv,
  loaderMatches
}
