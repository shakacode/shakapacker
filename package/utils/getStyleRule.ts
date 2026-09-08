import type { Config } from "../types"

const { canProcess, moduleExists } = require("./helpers")
const { requireOrError } = require("./requireOrError")
const config = require("../config") as Config
const inliningCss = require("./inliningCss")

interface StyleRule {
  test: RegExp
  use?: unknown[]
  type?: string
  parser?: Record<string, unknown>
  generator?: Record<string, unknown>
}

// css-loader, style-loader, and mini-css-extract-plugin are archived upstream,
// and Rspack v2 deprecated `experiments.css` in favor of `type: "css/auto"`
// rules. When css-loader is absent, hand CSS to the bundler's built-in parser
// instead of dropping the rule entirely. See docs/css_loader_deprecation.md.
const usesNativeCss = (): boolean => !moduleExists("css-loader")

// Determine CSS Modules export mode based on configuration
// 'named' (default): Use named exports with camelCaseOnly (v9 behavior)
// 'default': Use default exports with camelCase (v8 behavior)
const namedExportsEnabled = (): boolean =>
  config.css_modules_export_mode !== "default"

const tryPostcss = () =>
  canProcess("postcss-loader", (loaderPath: string) => ({
    loader: loaderPath,
    options: { sourceMap: true }
  }))

// The built-in parser's equivalents of the css-loader options below: `parser`
// replaces `modules`, and `generator.exportsConvention` takes kebab-case
// spellings of css-loader's `exportLocalsConvention` values.
const getNativeStyleRule = (
  test: RegExp,
  preprocessors: unknown[]
): StyleRule => {
  const useNamedExports = namedExportsEnabled()

  const rule: StyleRule = {
    test,
    type: "css/auto",
    parser: {
      namedExports: useNamedExports,
      // style-loader's runtime <style> injection is `exportType: "style"` here,
      // matching the inlining branch of the css-loader chain below.
      ...(inliningCss ? { exportType: "style" } : {})
    },
    generator: {
      exportsConvention: useNamedExports ? "camel-case-only" : "camel-case"
    }
  }

  // PostCSS and the preprocessors still run as loaders; the built-in parser
  // consumes their CSS output. Loaders apply right-to-left, so this keeps the
  // css-loader chain's order: preprocessor first, then PostCSS.
  const use = [tryPostcss(), ...preprocessors].filter(Boolean)

  if (use.length) {
    rule.use = use
  }

  return rule
}

const getStyleRule = (
  test: RegExp,
  preprocessors: unknown[] = []
): StyleRule | null => {
  if (usesNativeCss()) {
    return getNativeStyleRule(test, preprocessors)
  }

  // style-loader is required when using css modules with HMR on the webpack-dev-server

  const extractionPlugin =
    config.assets_bundler === "rspack"
      ? requireOrError("@rspack/core").CssExtractRspackPlugin.loader
      : requireOrError("mini-css-extract-plugin").loader

  const useNamedExports = namedExportsEnabled()

  const use = [
    inliningCss ? "style-loader" : extractionPlugin,
    {
      loader: require.resolve("css-loader"),
      options: {
        sourceMap: true,
        importLoaders: 2,
        modules: {
          auto: true,
          // Use named exports for v9 (default), or default exports for v8 compatibility
          namedExport: useNamedExports,
          // 'camelCaseOnly' with namedExport: true (v9 default)
          // 'camelCase' with namedExport: false (v8 behavior - exports both original and camelCase)
          exportLocalsConvention: useNamedExports
            ? "camelCaseOnly"
            : "camelCase"
        }
      }
    },
    tryPostcss(),
    ...preprocessors
  ].filter(Boolean)

  const result: StyleRule = {
    test,
    use
  }

  if (config.assets_bundler === "rspack") {
    result.type = "javascript/auto"
  }

  return result
}

export = { getStyleRule, usesNativeCss }
