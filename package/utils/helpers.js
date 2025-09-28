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
    let installCommand = ""
    let migrationHelp = ""
    
    if (configLoader === "babel") {
      installCommand = "npm install --save-dev babel-loader @babel/core @babel/preset-env @babel/plugin-transform-runtime @babel/runtime"
      migrationHelp = "\n\n💡 Tip: Consider migrating to SWC for 20x faster compilation:\n" +
                     "   1. Set javascript_transpiler: 'swc' in config/shakapacker.yml\n" +
                     "   2. Run: npm install @swc/core swc-loader"
    } else if (configLoader === "swc") {
      installCommand = "npm install --save-dev @swc/core swc-loader"
      migrationHelp = "\n\n✨ SWC is 20x faster than Babel with zero configuration!"
    } else if (configLoader === "esbuild") {
      installCommand = "npm install --save-dev esbuild esbuild-loader"
    }
    
    throw new Error(
      `Your Shakapacker config specified using ${configLoader}, but ${loaderName} package is not installed.\n\n` +
      `To fix this, run:\n  ${installCommand}${migrationHelp}`
    )
  }

  return fn()
}

const packageFullVersion = (packageName) => {
  // eslint-disable-next-line import/no-dynamic-require
  const packageJsonPath = require.resolve(`${packageName}/package.json`)
  // eslint-disable-next-line import/no-dynamic-require, global-require
  return require(packageJsonPath).version
}

const packageMajorVersion = (packageName) =>
  packageFullVersion(packageName).match(/^\d+/)[0]

module.exports = {
  isBoolean,
  ensureTrailingSlash,
  canProcess,
  moduleExists,
  loaderMatches,
  packageFullVersion,
  packageMajorVersion
}
