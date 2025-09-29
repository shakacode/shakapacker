// @ts-ignore - webpack is an optional peer dependency
import type { Configuration, RuleSetRule, RuleSetUseItem } from 'webpack'

export interface ShakapackerWebpackConfig extends Configuration {
  module?: Configuration['module'] & {
    rules?: RuleSetRule[]
  }
}

export interface ShakapackerRule extends RuleSetRule {
  test: RegExp
  use: RuleSetUseItem[]
}

export interface ShakapackerLoaderOptions {
  [key: string]: any
}

export interface ShakapackerLoader {
  loader: string
  options?: ShakapackerLoaderOptions
}

export type LoaderType = string | ShakapackerLoader

export interface LoaderUtils {
  resolveLoader(name: string): string
  createRule(test: RegExp, loaders: LoaderType[]): ShakapackerRule
  getStyleLoader(extract?: boolean): LoaderType
  getCssLoader(modules?: boolean): LoaderType
  getPostCssLoader(): LoaderType
  getSassLoader(): LoaderType
}