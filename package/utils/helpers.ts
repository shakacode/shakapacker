const errorHelpers = require("./errorHelpers")

const isBoolean = (str: string): boolean => /^true/.test(str) || /^false/.test(str)

const ensureTrailingSlash = (path: string): string => (path.endsWith("/") ? path : `${path}/`)

const resolvedPath = (packageName: string): string | null => {
  try {
    return require.resolve(packageName)
  } catch (error: unknown) {
    if (!errorHelpers.isModuleNotFoundError(error)) {
      throw error
    }
    return null
  }
}

const moduleExists = (packageName: string): boolean => !!resolvedPath(packageName)

const canProcess = <T = unknown>(rule: string, fn: (modulePath: string) => T): T | null => {
  const modulePath = resolvedPath(rule)

  if (modulePath) {
    return fn(modulePath)
  }

  return null
}

const loaderMatches = <T = unknown>(configLoader: string, loaderToCheck: string, fn: () => T): T | null => {
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

const packageFullVersion = (packageName: string): string => {
  try {
    // eslint-disable-next-line import/no-dynamic-require
    const packageJsonPath = require.resolve(`${packageName}/package.json`)
    // eslint-disable-next-line import/no-dynamic-require, global-require
    const packageJson = require(packageJsonPath) as { version: string }
    return packageJson.version
  } catch (error) {
    console.warn(`Failed to get version for package ${packageName}: ${errorHelpers.getErrorMessage(error)}`)
    return "0.0.0"
  }
}

const packageMajorVersion = (packageName: string): string => {
  const match = packageFullVersion(packageName).match(/^\d+/)
  return match ? match[0] : "0"
}

// Export as CommonJS for backward compatibility
export = {
  isBoolean,
  ensureTrailingSlash,
  canProcess,
  moduleExists,
  loaderMatches,
  packageFullVersion,
  packageMajorVersion,
  resolvedPath
}
