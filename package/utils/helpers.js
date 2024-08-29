const isBoolean = (str) => /^true/.test(str) || /^false/.test(str)

const ensureTrailingSlash = (path) => (path.endsWith("/") ? path : `${path}/`)

const resolvedPath = (packageName) => {
  try {
    return require.resolve(packageName)
  } catch (e) {
    if (e.code !== "MODULE_NOT_FOUND") {
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

const packageMajorVersion = (packageName) => {
  // eslint-disable-next-line import/no-dynamic-require
  const packageJsonPath = require.resolve(`${packageName}/package.json`)
  // eslint-disable-next-line import/no-dynamic-require, global-require
  return require(packageJsonPath).version.match(/^\d+/)[0]
}

module.exports = {
  isBoolean,
  ensureTrailingSlash,
  canProcess,
  moduleExists,
  loaderMatches,
  packageMajorVersion
}
