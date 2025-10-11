export interface ExportOptions {
  doctor?: boolean
  save?: boolean
  saveDir?: string
  stdout?: boolean
  bundler?: "webpack" | "rspack"
  env?: "development" | "production" | "test"
  clientOnly?: boolean
  serverOnly?: boolean
  output?: string
  format?: "yaml" | "json" | "inspect"
  annotate?: boolean
  verbose?: boolean
  depth?: number | null
  help?: boolean
  // New config file options
  init?: boolean
  configFile?: string
  build?: string
  listBuilds?: boolean
  allBuilds?: boolean
}

export interface ConfigMetadata {
  exportedAt: string
  bundler: string
  environment: string
  configFile: string
  configType: "client" | "server" | "all"
  configCount: number
  buildName?: string // New: name of the build from config file
  environmentVariables: {
    NODE_ENV?: string
    RAILS_ENV?: string
    CLIENT_BUNDLE_ONLY?: string
    SERVER_BUNDLE_ONLY?: string
  }
}

export interface FileOutput {
  filename: string
  content: string
  metadata: ConfigMetadata
}

// Config file schema types
export interface BundlerConfigFile {
  default_bundler?: "webpack" | "rspack"
  shakapacker_default_builds?: boolean
  builds: Record<string, BuildConfig>
}

export interface BuildConfig {
  description?: string
  bundler?: "webpack" | "rspack"
  environment?: Record<string, string>
  bundler_env?: Record<string, string | boolean>
  outputs?: string[]
  config?: string
}

export interface ResolvedBuildConfig {
  name: string
  description?: string
  bundler: "webpack" | "rspack"
  environment: Record<string, string>
  bundlerEnvArgs: string[] // Converted bundler_env to CLI args
  outputs: string[]
  configFile?: string
}
