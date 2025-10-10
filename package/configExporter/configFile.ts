import { existsSync, readFileSync } from "fs"
import { resolve } from "path"
import { load as loadYaml } from "js-yaml"
import {
  BundlerConfigFile,
  BuildConfig,
  ResolvedBuildConfig,
  ExportOptions
} from "./types"

export class ConfigFileLoader {
  private configFilePath: string

  constructor(configFilePath?: string) {
    this.configFilePath =
      configFilePath || resolve(process.cwd(), ".bundler-config.yml")
  }

  exists(): boolean {
    return existsSync(this.configFilePath)
  }

  load(): BundlerConfigFile {
    if (!this.exists()) {
      throw new Error(
        `Config file not found: ${this.configFilePath}\n` +
          `Run 'bin/export-bundler-config --init' to generate a sample config file.`
      )
    }

    try {
      const content = readFileSync(this.configFilePath, "utf8")
      const parsed = loadYaml(content) as BundlerConfigFile

      this.validate(parsed)
      return parsed
    } catch (error: any) {
      throw new Error(
        `Failed to load config file ${this.configFilePath}: ${error.message}`
      )
    }
  }

  private validate(config: BundlerConfigFile): void {
    if (!config.builds || typeof config.builds !== "object") {
      throw new Error("Config file must contain a 'builds' object")
    }

    if (Object.keys(config.builds).length === 0) {
      throw new Error("Config file must contain at least one build")
    }

    if (
      config.default_bundler &&
      config.default_bundler !== "webpack" &&
      config.default_bundler !== "rspack"
    ) {
      throw new Error(
        `Invalid default_bundler '${config.default_bundler}'. Must be 'webpack' or 'rspack'.`
      )
    }

    // Validate each build
    for (const [name, build] of Object.entries(config.builds)) {
      if (
        build.bundler &&
        build.bundler !== "webpack" &&
        build.bundler !== "rspack"
      ) {
        throw new Error(
          `Invalid bundler '${build.bundler}' in build '${name}'. Must be 'webpack' or 'rspack'.`
        )
      }

      if (build.bundler_env && typeof build.bundler_env !== "object") {
        throw new Error(
          `Invalid bundler_env in build '${name}'. Must be an object.`
        )
      }

      if (build.environment && typeof build.environment !== "object") {
        throw new Error(
          `Invalid environment in build '${name}'. Must be an object.`
        )
      }

      if (build.outputs && !Array.isArray(build.outputs)) {
        throw new Error(
          `Invalid outputs in build '${name}'. Must be an array of strings.`
        )
      }
    }
  }

  resolveBuild(
    buildName: string,
    options: ExportOptions,
    defaultBundler: "webpack" | "rspack"
  ): ResolvedBuildConfig {
    const config = this.load()
    const build = config.builds[buildName]

    if (!build) {
      const available = Object.keys(config.builds).join(", ")
      throw new Error(
        `Build '${buildName}' not found in config file.\n` +
          `Available builds: ${available}\n` +
          `Use --list-builds to see all available builds.`
      )
    }

    // Resolve bundler with precedence
    const bundler = this.resolveBundler(
      options.bundler,
      build.bundler,
      config.default_bundler,
      defaultBundler
    )

    // Expand environment variables
    const environment = this.expandEnvironmentVariables(
      build.environment || {},
      bundler
    )

    // Convert bundler_env to CLI args
    const bundlerEnvArgs = this.convertBundlerEnvToArgs(build.bundler_env || {})

    // Resolve outputs
    const outputs = build.outputs || []

    // Resolve config file
    const configFile = build.config
      ? this.expandEnvironmentVariables({ config: build.config }, bundler)
          .config
      : undefined

    return {
      name: buildName,
      description: build.description,
      bundler,
      environment,
      bundlerEnvArgs,
      outputs,
      configFile
    }
  }

  private resolveBundler(
    cliFlag?: "webpack" | "rspack",
    buildBundler?: "webpack" | "rspack",
    defaultBundler?: "webpack" | "rspack",
    fallback: "webpack" | "rspack" = "webpack"
  ): "webpack" | "rspack" {
    return cliFlag || buildBundler || defaultBundler || fallback
  }

  private expandEnvironmentVariables(
    vars: Record<string, string>,
    bundler: string
  ): Record<string, string> {
    const expanded: Record<string, string> = {}

    for (const [key, value] of Object.entries(vars)) {
      expanded[key] = this.expandString(value, bundler)
    }

    return expanded
  }

  private expandString(str: string, bundler: string): string {
    // Replace \${BUNDLER} with actual bundler
    let expanded = str.replace(/\$\{BUNDLER\}/g, bundler)

    // Replace ${VAR:-default} with VAR value or default
    expanded = expanded.replace(
      /\$\{([^}:]+):-([^}]*)\}/g,
      (_, varName, defaultValue) => {
        return process.env[varName] || defaultValue
      }
    )

    // Replace ${VAR} with VAR value
    expanded = expanded.replace(/\$\{([^}:]+)\}/g, (_, varName) => {
      return process.env[varName] || ""
    })

    return expanded
  }

  private convertBundlerEnvToArgs(
    bundlerEnv: Record<string, string | boolean>
  ): string[] {
    const args: string[] = []

    for (const [key, value] of Object.entries(bundlerEnv)) {
      if (value === true) {
        // Boolean true becomes --env key
        args.push("--env", key)
      } else if (typeof value === "string") {
        // String value becomes --env key=value
        args.push("--env", `${key}=${value}`)
      }
      // false or other values are ignored
    }

    return args
  }

  listBuilds(): void {
    const config = this.load()
    const builds = config.builds

    console.log(`\nAvailable builds in ${this.configFilePath}:\n`)

    for (const [name, build] of Object.entries(builds)) {
      const bundler =
        build.bundler || config.default_bundler || "webpack (default)"
      const outputs = build.outputs ? build.outputs.join(", ") : "auto-detect"

      console.log(`  ${name}`)
      if (build.description) {
        console.log(`    Description: ${build.description}`)
      }
      console.log(`    Bundler: ${bundler}`)
      console.log(`    Outputs: ${outputs}`)
      console.log()
    }
  }
}

export function generateSampleConfigFile(): string {
  // Using ${'$'} to escape template literal substitution in comments
  return `# Bundler Build Configurations
# Generated by: bin/export-bundler-config --init
#
# This file defines build configurations for exporting bundler configs.
# You can define multiple builds with different environments and settings.

# Default bundler for all builds (can be overridden per-build or with --webpack/--rspack flags)
default_bundler: webpack  # Options: webpack | rspack

builds:
  # ============================================================================
  # DEVELOPMENT BUILDS
  # ============================================================================

  # Development: Client and Server bundles
  dev:
    description: Build admin and consumer bundles for dev env

    # Shell environment variables (NODE_ENV, RAILS_ENV, etc.)
    environment:
      NODE_OPTIONS: "--max-old-space-size=4096"
      NODE_ENV: development
      RAILS_ENV: development

    # Bundler-specific --env arguments
    # Key-value pairs: "env: dev" becomes "--env env=dev"
    # Boolean true: "instrumented: true" becomes "--env instrumented"
    bundler_env:
      env: dev

    # Output types (maps to config array indices)
    # Used for file naming and metadata
    outputs:
      - client
      - server

    # Optional: Override config file path
    # Supports ${"$"}{BUNDLER} substitution (webpack/rspack)
    # config: ${"$"}{BUNDLER}.config.ts  # Defaults to auto-detected file

  # Development: Server bundle only
  dev-server:
    description: Build server bundle for dev env
    environment:
      NODE_ENV: development
      RAILS_ENV: development
    bundler_env:
      env: serverBundleDev
    outputs:
      - server

  # ============================================================================
  # TEST BUILDS
  # ============================================================================

  # Cypress development
  cypress-dev:
    description: Build for Cypress development
    environment:
      NODE_OPTIONS: "--max-old-space-size=4096"
      BABEL_ENV: test
      RAILS_ENV: test
      NODE_ENV: test
    bundler_env:
      env: dev
    outputs:
      - client
      - server

  # ============================================================================
  # PRODUCTION BUILDS
  # ============================================================================

  # Production: Server bundle
  prod-server:
    description: Build server bundle for production
    environment:
      NODE_ENV: production
      # Supports shell-style default values: ${"$"}{VAR:-default}
      RAILS_ENV: ${"$"}{RAILS_ENV:-production}
    bundler_env:
      env: serverBundleProd
    outputs:
      - server

  # Production: Server with instrumentation
  prod-instrumented:
    description: Build server bundle with instrumentation
    environment:
      NODE_ENV: production
      RAILS_ENV: ${"$"}{RAILS_ENV:-production}
    bundler_env:
      env: serverBundleProd
      instrumented: true      # Becomes --env instrumented
      modernBrowsers: true    # Becomes --env modernBrowsers
    outputs:
      - server

  # Production: Client bundles
  prod-consumer:
    description: Build consumer bundle for production
    environment:
      NODE_ENV: production
      RAILS_ENV: production
    bundler_env:
      env: prod
    outputs:
      - client

  # Production: Legacy bundles
  prod-legacy:
    description: Build polyfilled bundles for production
    environment:
      NODE_ENV: production
      RAILS_ENV: production
    bundler_env:
      env: prod
      legacy: true
    outputs:
      - client

# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Initialize this config file:
#   bin/export-bundler-config --init
#
# List all available builds:
#   bin/export-bundler-config --list-builds
#
# Export specific build:
#   bin/export-bundler-config --build=dev --save
#   Creates: webpack-dev-client.yml, webpack-dev-server.yml
#
# Export with rspack instead:
#   bin/export-bundler-config --build=dev --save --rspack
#   Creates: rspack-dev-client.yml, rspack-dev-server.yml
#
# Export to stdout for inspection:
#   bin/export-bundler-config --build=cypress-dev
#
# Doctor mode (export all for troubleshooting):
#   bin/export-bundler-config --doctor --config-file=.bundler-config.yml
#
# ============================================================================
# VARIABLE EXPANSION
# ============================================================================
#
# Supported variable substitutions:
#   ${"$"}{BUNDLER}           - Replaced with 'webpack' or 'rspack'
#   ${"$"}{VAR}               - Replaced with environment variable value
#   ${"$"}{VAR:-default}      - Replaced with VAR or 'default' if not set
#
# Examples:
#   config: ${"$"}{BUNDLER}.config.ts
#   RAILS_ENV: ${"$"}{RAILS_ENV:-production}
#
`
}
