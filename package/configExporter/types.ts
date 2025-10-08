export interface ExportOptions {
  doctor?: boolean
  save?: boolean
  saveDir?: string
  bundler?: "webpack" | "rspack" | null
  env?: "development" | "production" | "test"
  clientOnly?: boolean
  serverOnly?: boolean
  output?: string | null
  format?: "yaml" | "json" | "inspect" | null
  annotate?: boolean | null
  verbose?: boolean
  depth?: number | null
  help?: boolean
}

export interface ConfigMetadata {
  exportedAt: string
  bundler: string
  environment: string
  configFile: string
  configType: "client" | "server" | "all"
  configCount: number
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
