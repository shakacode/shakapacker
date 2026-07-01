import { moduleExists, packageFullVersion } from "../utils/helpers"
import type { ConfigAPI, PluginItem } from "@babel/core"

const CORE_JS_VERSION_REGEX = /^\d+\.\d+/

const babelMajorVersion = (api: ConfigAPI & { version?: string }): number => {
  const version = api.version?.match(/^\d+/)
  return version ? parseInt(version[0], 10) : 7
}

const coreJsVersion = (): string => {
  try {
    const version = packageFullVersion("core-js").match(CORE_JS_VERSION_REGEX)
    return version?.[0] ?? "3.8"
  } catch (e) {
    const error = e as NodeJS.ErrnoException
    if (error.code !== "MODULE_NOT_FOUND") {
      throw e
    }

    return "3.8"
  }
}

export = function config(api: ConfigAPI): {
  presets: PluginItem[]
  plugins: PluginItem[]
} {
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

  const isBabel8 = babelMajorVersion(api) >= 8
  const presetEnvOptions = isBabel8
    ? {
        modules: "auto",
        exclude: ["transform-typeof-symbol"]
      }
    : {
        useBuiltIns: "entry",
        corejs: coreJsVersion(),
        modules: "auto",
        bugfixes: true,
        exclude: ["transform-typeof-symbol"]
      }

  const presets: PluginItem[] = [
    isTestEnv && ["@babel/preset-env", { targets: { node: "current" } }],
    (isProductionEnv || isDevelopmentEnv) && [
      "@babel/preset-env",
      presetEnvOptions
    ],
    moduleExists("@babel/preset-typescript") && "@babel/preset-typescript"
  ].filter(Boolean) as PluginItem[]

  const plugins: PluginItem[] = [
    isBabel8
      ? "@babel/plugin-transform-runtime"
      : ["@babel/plugin-transform-runtime", { helpers: false }]
  ].filter(Boolean) as PluginItem[]

  return {
    presets,
    plugins
  }
}
