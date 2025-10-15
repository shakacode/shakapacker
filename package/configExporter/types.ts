export interface ExportOptions {
  doctor?: boolean
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
  // Validation options
  validate?: boolean
  validateBuild?: string
}

export interface ConfigMetadata {
  exportedAt: string
  bundler: string
  environment: string
  configFile: string
  configType: "client" | "server" | "all" | "client-hmr"
  configCount: number
  buildName?: string // New: name of the build from config file
  environmentVariables: {
    NODE_ENV?: string
    RAILS_ENV?: string
    CLIENT_BUNDLE_ONLY?: string
    SERVER_BUNDLE_ONLY?: string
    WEBPACK_SERVE?: string
    HMR?: string
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
  shakapacker_doctor_default_builds_here?: boolean
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

export interface BuildValidationResult {
  buildName: string
  success: boolean
  errors: string[]
  warnings: string[]
  output: string[]
  outputs?: string[] // Build outputs (e.g., ["client", "server"])
  configFile?: string // Config file path if specified
  outputPath?: string // Output directory where files are written
  startTime?: number // Unix timestamp in milliseconds
  endTime?: number // Unix timestamp in milliseconds
  duration?: number // Duration in milliseconds
}
