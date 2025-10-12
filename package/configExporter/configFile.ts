import { existsSync, readFileSync } from "fs"
import { resolve, relative, isAbsolute } from "path"
import { load as loadYaml, FAILSAFE_SCHEMA } from "js-yaml"
import {
  BundlerConfigFile,
  BuildConfig,
  ResolvedBuildConfig,
  ExportOptions
} from "./types"

/**
 * Loads and validates bundler configuration files
 * @example
 * const loader = new ConfigFileLoader('.bundler-config.yml')
 * const config = loader.load()
 */
export class ConfigFileLoader {
  private configFilePath: string

  /**
   * @param configFilePath - Path to config file (defaults to .bundler-config.yml in cwd)
   * @throws Error if path is outside project directory
   */
  constructor(configFilePath?: string) {
    this.configFilePath =
      configFilePath || resolve(process.cwd(), ".bundler-config.yml")
    this.validateConfigPath()
  }

  /**
   * Validates that the config file path is within the project directory
   * to prevent path traversal attacks
   * @throws Error if path traversal is detected
   */
  private validateConfigPath(): void {
    const absPath = resolve(this.configFilePath)
    const cwd = process.cwd()
    const rel = relative(cwd, absPath)

    if (rel.startsWith("..") || (isAbsolute(rel) && !absPath.startsWith(cwd))) {
      throw new Error(
        `Config file must be within project directory. Attempted path: ${this.configFilePath}`
      )
    }
  }

  /**
   * Checks if the config file exists
   * @returns true if file exists, false otherwise
   */
  exists(): boolean {
    return existsSync(this.configFilePath)
  }

  /**
   * Loads and validates the config file
   * @returns Parsed and validated config file
   * @throws Error if file doesn't exist, is invalid YAML, or fails validation
   */
  load(): BundlerConfigFile {
    if (!this.exists()) {
      throw new Error(
        `Config file not found: ${this.configFilePath}\n` +
          `Run 'bin/export-bundler-config --init' to generate a sample config file.`
      )
    }

    try {
      const content = readFileSync(this.configFilePath, "utf8")
      // Use FAILSAFE_SCHEMA to prevent code execution via YAML parsing
      const parsed = loadYaml(content, {
        schema: FAILSAFE_SCHEMA,
        json: true
      }) as BundlerConfigFile

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
      // Guard: ensure build is a non-null plain object
      if (build == null || typeof build !== "object" || Array.isArray(build)) {
        throw new Error(
          `Invalid build '${name}': must be an object, got ${build === null ? "null" : Array.isArray(build) ? "array" : typeof build}`
        )
      }

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

  /**
   * Resolves a build configuration by name
   * @param buildName - Name of the build from config file
   * @param options - CLI options that may override build settings
   * @param defaultBundler - Fallback bundler if not specified
   * @returns Resolved build configuration with all settings applied
   * @throws Error if build name not found
   */
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

    // Resolve and validate outputs
    const outputs = build.outputs || []

    // Validate edge cases
    if (outputs.length === 0) {
      throw new Error(
        `Build '${buildName}' has empty outputs array. ` +
          `Please specify at least one output type (client, server, or all).`
      )
    }

    // Check for duplicates
    const uniqueOutputs = new Set(outputs)
    if (uniqueOutputs.size !== outputs.length) {
      throw new Error(
        `Build '${buildName}' has duplicate output types. ` +
          `Each output type should appear only once.`
      )
    }

    // Resolve config file
    let configFile: string | undefined
    if (build.config) {
      configFile = this.expandEnvironmentVariables(
        { config: build.config },
        bundler
      ).config

      // Validate config file path (prevent path traversal)
      if (configFile) {
        // Normalize Windows backslashes for validation
        const configFileNormalized = configFile.replace(/\\/g, "/")
        if (
          configFileNormalized.includes("..") ||
          !configFileNormalized.startsWith("config/")
        ) {
          throw new Error(
            `Invalid config file path in build '${buildName}': "${configFile}". ` +
              `Config files must be within the config/ directory.`
          )
        }
      }
    }

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
        // Validate env var name to prevent regex injection
        if (!this.isValidEnvVarName(varName)) {
          console.warn(
            `[Config Exporter] Warning: Invalid environment variable name: ${varName}`
          )
          return `\${${varName}:-${defaultValue}}`
        }
        return process.env[varName] || defaultValue
      }
    )

    // Replace ${VAR} with VAR value
    expanded = expanded.replace(/\$\{([^}:]+)\}/g, (_, varName) => {
      // Validate env var name to prevent regex injection
      if (!this.isValidEnvVarName(varName)) {
        console.warn(
          `[Config Exporter] Warning: Invalid environment variable name: ${varName}`
        )
        return `\${${varName}}`
      }
      return process.env[varName] || ""
    })

    return expanded
  }

  /**
   * Validates that an environment variable name matches the standard format
   * Must start with letter or underscore, followed by letters, numbers, or underscores
   * @param name - The variable name to validate
   * @returns true if valid, false otherwise
   */
  private isValidEnvVarName(name: string): boolean {
    return /^[A-Z_][A-Z0-9_]*$/i.test(name)
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

  /**
   * Lists all available builds from the config file
   * Prints formatted output to console
   * @throws Error if config file doesn't exist or is invalid
   */
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

/**
 * Generates a sample configuration file with examples and documentation
 * @returns YAML content as string ready to be written to file
 */
export function generateSampleConfigFile(): string {
  // Using ${'$'} to escape template literal substitution in comments
  return `# Bundler Build Configurations
# Generated by: bin/export-bundler-config --init
#
# This file defines build configurations for exporting bundler configs.
# You can define multiple builds with different environments and settings.

# Default bundler for all builds (can be overridden per-build or with --webpack/--rspack flags)
default_bundler: rspack  # Options: webpack | rspack

# Use these builds as defaults for --doctor mode (optional)
# When set to true, --doctor will export ALL builds defined below instead of hardcoded defaults
# shakapacker_default_builds: true

builds:
  # ============================================================================
  # DEVELOPMENT WITH HMR (Hot Module Replacement)
  # ============================================================================
  # For Procfile.dev: WEBPACK_SERVE=true bin/shakapacker-dev-server
  # Creates client bundle with React Fast Refresh enabled

  dev-hmr:
    description: Client bundle with HMR (React Fast Refresh)
    environment:
      NODE_ENV: development
      RAILS_ENV: development
      WEBPACK_SERVE: "true"
    outputs:
      - client

  # ============================================================================
  # DEVELOPMENT (Standard)
  # ============================================================================
  # For Procfile.dev-static-assets: bin/shakapacker --watch
  # Creates both client and server bundles without HMR

  dev:
    description: Development client and server bundles (no HMR)
    environment:
      NODE_ENV: development
      RAILS_ENV: development
    outputs:
      - client
      - server

  # ============================================================================
  # PRODUCTION
  # ============================================================================
  # For asset precompilation: RAILS_ENV=production bin/shakapacker
  # Creates optimized production bundles

  prod:
    description: Production client and server bundles
    environment:
      NODE_ENV: production
      RAILS_ENV: production
    outputs:
      - client
      - server

  # ============================================================================
  # ADDITIONAL EXAMPLES
  # ============================================================================

  # Example: Single bundle only (client or server)
  # dev-client-only:
  #   description: Development client bundle only
  #   environment:
  #     NODE_ENV: development
  #     RAILS_ENV: development
  #     CLIENT_BUNDLE_ONLY: "yes"
  #   outputs:
  #     - client

  # Example: Using bundler --env flags
  # prod-modern:
  #   description: Production with custom webpack/rspack --env flags
  #   environment:
  #     NODE_ENV: production
  #     RAILS_ENV: production
  #   bundler_env:
  #     target: modern         # Becomes: --env target=modern
  #     instrumented: true     # Becomes: --env instrumented
  #   outputs:
  #     - client
  #     - server

  # Example: Variable substitution with defaults
  # staging:
  #   description: Staging environment with variable substitution
  #   environment:
  #     NODE_ENV: production
  #     RAILS_ENV: ${"$"}{RAILS_ENV:-staging}  # Use env var or default to 'staging'
  #   outputs:
  #     - client
  #     - server

  # Example: Custom config file path (uses ${"$"}{BUNDLER} substitution)
  # custom-config:
  #   description: Using custom config file location
  #   environment:
  #     NODE_ENV: development
  #   config: config/${"$"}{BUNDLER}/${"$"}{BUNDLER}.config.js
  #   outputs:
  #     - client
  #     - server

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
# Export development build configs:
#   bin/export-bundler-config --build=dev-hmr --save
#   Creates: rspack-dev-hmr-client.yml
#
#   bin/export-bundler-config --build=dev --save
#   Creates: rspack-dev-client.yml, rspack-dev-server.yml
#
# Export production build:
#   bin/export-bundler-config --build=prod --save
#   Creates: rspack-prod-client.yml, rspack-prod-server.yml
#
# Use webpack instead of default rspack:
#   bin/export-bundler-config --build=prod --save --webpack
#   Creates: webpack-prod-client.yml, webpack-prod-server.yml
#
# Export to stdout for inspection (no files created):
#   bin/export-bundler-config --build=dev
#
# Export to custom directory:
#   bin/export-bundler-config --build=prod --save-dir=./debug
#
# Doctor mode (comprehensive troubleshooting):
#   bin/export-bundler-config --doctor
#   Creates files in: shakapacker-config-exports/
#
`
}
