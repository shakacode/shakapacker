"use strict";
const { isModuleNotFoundError, getErrorMessage } = require("./errorHelpers");
const isBoolean = (str) => /^true/.test(str) || /^false/.test(str);
const ensureTrailingSlash = (path) => (path.endsWith("/") ? path : `${path}/`);
const resolvedPath = (packageName) => {
    try {
        return require.resolve(packageName);
    }
    catch (error) {
        if (!isModuleNotFoundError(error)) {
            throw error;
        }
        return null;
    }
};
const moduleExists = (packageName) => !!resolvedPath(packageName);
const canProcess = (rule, fn) => {
  const modulePath = resolvedPath(rule)

  if (modulePath) {
    return fn(modulePath)
  }

  return null
}

const validateBabelDependencies = () => {
  // Only validate core dependencies that are absolutely required
  // Additional packages like presets are optional and project-specific
  const coreRequiredPackages = ["@babel/core", "babel-loader"]

  const missingCorePackages = coreRequiredPackages.filter(
    (pkg) => !moduleExists(pkg)
  )

  if (missingCorePackages.length > 0) {
    const installCommand = `npm install --save-dev ${missingCorePackages.join(" ")}`

    // Check for commonly needed packages and suggest them
    const suggestedPackages = [
      "@babel/preset-env",
      "@babel/plugin-transform-runtime",
      "@babel/runtime"
    ]

    const missingSuggested = suggestedPackages.filter(
      (pkg) => !moduleExists(pkg)
    )
    let additionalHelp = ""

    if (missingSuggested.length > 0) {
      additionalHelp =
        `\n\nYou may also need: ${missingSuggested.join(", ")}\n` +
        `Install with: npm install --save-dev ${missingSuggested.join(" ")}`
    }

    throw new Error(
      `Babel is configured but core packages are missing: ${missingCorePackages.join(", ")}\n\n` +
        `To fix this, run:\n  ${installCommand}${additionalHelp}\n\n` +
        `💡 Tip: Consider migrating to SWC for 20x faster compilation:\n` +
        `   1. Set javascript_transpiler: 'swc' in config/shakapacker.yml\n` +
        `   2. Run: npm install @swc/core swc-loader`
    )
  }
}

const loaderMatches = (configLoader, loaderToCheck, fn) => {
  if (configLoader !== loaderToCheck) {
    return null
  }

  const loaderName = `${configLoader}-loader`

  // Special validation for babel to check all dependencies
  if (configLoader === "babel") {
    validateBabelDependencies()
  }

  if (!moduleExists(loaderName)) {
    let installCommand = ""
    let migrationHelp = ""

    if (configLoader === "babel") {
      installCommand =
        "npm install --save-dev babel-loader @babel/core @babel/preset-env @babel/plugin-transform-runtime @babel/runtime"
      migrationHelp =
        "\n\n💡 Tip: Consider migrating to SWC for 20x faster compilation:\n" +
        "   1. Set javascript_transpiler: 'swc' in config/shakapacker.yml\n" +
        "   2. Run: npm install @swc/core swc-loader"
    } else if (configLoader === "swc") {
      installCommand = "npm install --save-dev @swc/core swc-loader"
      migrationHelp =
        "\n\n✨ SWC is 20x faster than Babel with zero configuration!"
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
    try {
        // eslint-disable-next-line import/no-dynamic-require
        const packageJsonPath = require.resolve(`${packageName}/package.json`);
        // eslint-disable-next-line import/no-dynamic-require, global-require
        const packageJson = require(packageJsonPath);
        return packageJson.version;
    }
    catch (error) {
        console.warn(`Failed to get version for package ${packageName}: ${getErrorMessage(error)}`);
        return "0.0.0";
    }
};
const packageMajorVersion = (packageName) => {
    const match = packageFullVersion(packageName).match(/^\d+/);
    return match ? match[0] : "0";
};
module.exports = {
  isBoolean,
  ensureTrailingSlash,
  canProcess,
  moduleExists,
  validateBabelDependencies,
  loaderMatches,
  packageFullVersion,
  packageMajorVersion,
  resolvedPath
}
