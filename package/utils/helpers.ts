import { isModuleNotFoundError, getErrorMessage } from "./errorHelpers"

const isBoolean = (str: string): boolean => /^true/.test(str) || /^false/.test(str)

const ensureTrailingSlash = (path: string): string => (path.endsWith("/") ? path : `${path}/`)

const resolvedPath = (packageName: string): string | null => {
  try {
    return require.resolve(packageName)
  } catch (error: unknown) {
    if (!isModuleNotFoundError(error)) {
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
      `Your Shakapacker config specified using ${configLoader}, but ${loaderName} package is not installed.\n` +
      `\nTo fix this issue, run one of the following commands:\n` +
      `  npm install --save-dev ${loaderName}\n` +
      `  yarn add --dev ${loaderName}\n` +
      `\nOr change your 'javascript_transpiler' setting in shakapacker.yml to use a different loader.`
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
    console.warn(
      `Failed to get version for package ${packageName}: ${getErrorMessage(error)}\n` +
      `This may indicate the package is not properly installed. Try reinstalling with:\n` +
      `  npm install ${packageName}\n` +
      `  yarn add ${packageName}`
    )
    return "0.0.0"
  }
}

const packageMajorVersion = (packageName: string): string => {
  const match = packageFullVersion(packageName).match(/^\d+/)
  return match ? match[0] : "0"
}

export {
  isBoolean,
  ensureTrailingSlash,
  canProcess,
  moduleExists,
  loaderMatches,
  packageFullVersion,
  packageMajorVersion,
  resolvedPath
}
