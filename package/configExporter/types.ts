export interface ExportOptions {
  doctor?: boolean
  save?: boolean
  saveDir?: string
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
}

export interface ConfigMetadata {
  exportedAt: string
  bundler: string
  environment: string
  configFile: string
  configType: "client" | "server" | "all" | "client-hmr"
  configCount: number
  environmentVariables: {
    NODE_ENV?: string
    RAILS_ENV?: string
    CLIENT_BUNDLE_ONLY?: string
    SERVER_BUNDLE_ONLY?: string
    WEBPACK_SERVE?: string
  }
}

export interface FileOutput {
  filename: string
  content: string
  metadata: ConfigMetadata
}
