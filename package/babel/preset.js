const helpers_1 = require("../utils/helpers")
const CORE_JS_VERSION_REGEX = /^\d+\.\d+/
const coreJsVersion = () => {
  try {
    const version = (0, helpers_1.packageFullVersion)("core-js").match(
      CORE_JS_VERSION_REGEX
    )
    return version?.[0] ?? "3.8"
  } catch (e) {
    const error = e
    if (error.code !== "MODULE_NOT_FOUND") {
      throw e
    }
    return "3.8"
  }
}
module.exports = function config(api) {
  const validEnv = ["development", "test", "production"]
  const currentEnv = api.env()
  const isDevelopmentEnv = api.env("development")
  const isProductionEnv = api.env("production")
  const isTestEnv = api.env("test")
  if (!validEnv.includes(currentEnv)) {
    throw new Error(
      `Please specify a valid NODE_ENV or BABEL_ENV environment variable. Valid values are "development", "test", and "production". Instead, received: "${currentEnv}".`
    )
  }
  const presets = [
    isTestEnv && ["@babel/preset-env", { targets: { node: "current" } }],
    (isProductionEnv || isDevelopmentEnv) && [
      "@babel/preset-env",
      {
        useBuiltIns: "entry",
        corejs: coreJsVersion(),
        modules: "auto",
        bugfixes: true,
        exclude: ["transform-typeof-symbol"]
      }
    ],
    (0, helpers_1.moduleExists)("@babel/preset-typescript") &&
      "@babel/preset-typescript"
  ].filter(Boolean)
  const plugins = [
    ["@babel/plugin-transform-runtime", { helpers: false }]
  ].filter(Boolean)
  return {
    presets,
    plugins
  }
}
