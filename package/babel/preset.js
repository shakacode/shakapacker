const { moduleExists, packageFullVersion } = require("../utils/helpers")

const coreJsVersion = () => {
  try {
    return packageFullVersion("core-js").match(/^\d+\.\d+/)[0]
  } catch (e) {
    if (e.code !== "MODULE_NOT_FOUND") {
      throw e
    }

    return "3.8"
  }
}

/** @param api {import("@babel/core").ConfigAPI} */
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

  return {
    presets: [
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
      moduleExists("@babel/preset-typescript") && "@babel/preset-typescript"
    ].filter(Boolean),
    plugins: [["@babel/plugin-transform-runtime", { helpers: false }]].filter(
      Boolean
    )
  }
}
