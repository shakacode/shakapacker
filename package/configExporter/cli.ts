// This will be a substantial file - the main CLI entry point
// Migrating from bin/export-bundler-config but streamlined for TypeScript

import { existsSync, readFileSync, writeFileSync } from "fs"
import { resolve, dirname, sep, delimiter, basename } from "path"
import { inspect } from "util"
import { load as loadYaml } from "js-yaml"
import yargs from "yargs"
import { ExportOptions, ConfigMetadata, FileOutput } from "./types"
import { YamlSerializer } from "./yamlSerializer"
import { FileWriter } from "./fileWriter"
import { ConfigFileLoader, generateSampleConfigFile } from "./configFile"
import { BuildValidator } from "./buildValidator"

// Read version from package.json
const packageJson = JSON.parse(
  readFileSync(resolve(__dirname, "../../package.json"), "utf8")
)
const VERSION = packageJson.version

/**
 * Environment variable names that can be set by build configurations
 */
const BUILD_ENV_VARS = [
  "NODE_ENV",
  "RAILS_ENV",
  "NODE_OPTIONS",
  "BABEL_ENV",
  "WEBPACK_SERVE",
  "CLIENT_BUNDLE_ONLY",
  "SERVER_BUNDLE_ONLY"
] as const

/**
 * Saves current values of build environment variables for later restoration
 * @returns Object mapping variable names to their current values (or undefined)
 */
function saveBuildEnvironmentVariables(): Record<string, string | undefined> {
  const saved: Record<string, string | undefined> = {}
  BUILD_ENV_VARS.forEach((varName) => {
    saved[varName] = process.env[varName]
  })
  return saved
}

/**
 * Restores previously saved environment variable values
 * @param saved - Object mapping variable names to their original values
 */
function restoreBuildEnvironmentVariables(
  saved: Record<string, string | undefined>
): void {
  BUILD_ENV_VARS.forEach((varName) => {
    const originalValue = saved[varName]
    if (originalValue === undefined) {
      delete process.env[varName]
    } else {
      process.env[varName] = originalValue
    }
  })
}

/**
 * Clears all whitelisted build environment variables from process.env
 * to prevent environment variable leakage between builds
 */
function clearBuildEnvironmentVariables(): void {
  BUILD_ENV_VARS.forEach((varName) => {
    delete process.env[varName]
  })
}

// Main CLI entry point
export async function run(args: string[]): Promise<number> {
  try {
    const options = parseArguments(args)

    // Handle --init command
    if (options.init) {
      return runInitCommand(options)
    }

    // Handle --list-builds command
    if (options.listBuilds) {
      return runListBuildsCommand(options)
    }

    // Handle --validate or --validate-build command
    if (options.validate || options.validateBuild) {
      return await runValidateCommand(options)
    }

    // Handle --all-builds command
    if (options.allBuilds) {
      return runAllBuildsCommand(options)
    }

    // Set up environment
    const appRoot = findAppRoot()
    process.chdir(appRoot)
    setupNodePath(appRoot)

    // Apply defaults
    const resolvedOptions = applyDefaults(options)

    // Validate after defaults are applied
    if (resolvedOptions.annotate && resolvedOptions.format !== "yaml") {
      throw new Error(
        "Annotation requires YAML format. Use --no-annotate or --format=yaml."
      )
    }

    // Validate --build requires config file
    if (resolvedOptions.build) {
      const loader = new ConfigFileLoader(resolvedOptions.configFile)
      if (!loader.exists()) {
        const configPath =
          resolvedOptions.configFile || "config/shakapacker-builds.yml"
        throw new Error(
          `--build requires a config file but ${configPath} not found. Run --init to create it.`
        )
      }
    }

    // Execute based on mode
    if (resolvedOptions.doctor) {
      await runDoctorMode(resolvedOptions, appRoot)
    } else if (resolvedOptions.stdout) {
      // Explicit stdout mode
      await runStdoutMode(resolvedOptions, appRoot)
    } else if (resolvedOptions.output) {
      // Save to single file
      await runSingleFileMode(resolvedOptions, appRoot)
    } else {
      // Default: save to directory
      await runSaveMode(resolvedOptions, appRoot)
    }

    return 0
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error(`[Config Exporter] Error: ${errorMessage}`)
    return 1
  }
}

function parseArguments(args: string[]): ExportOptions {
  const argv = yargs(args)
    .version(VERSION)
    .usage(
      `Shakapacker Config Exporter

Exports webpack or rspack configuration in a verbose, human-readable format
for comparison and analysis.

QUICK START (for troubleshooting):
  bin/shakapacker-config --doctor

  Exports annotated YAML configs for both development and production.
  Creates separate files for client and server bundles.
  Best for debugging, AI analysis, and comparing configurations.`
    )
    // Build Configuration Options (most important - users interact with these most)
    .option("init", {
      type: "boolean",
      default: false,
      description:
        "Generate config/shakapacker-builds.yml (use with --ssr for SSR builds)"
    })
    .option("ssr", {
      type: "boolean",
      default: false,
      description: "Include SSR builds when using --init"
    })
    .option("list-builds", {
      type: "boolean",
      default: false,
      description: "List all available builds from config file"
    })
    .option("build", {
      type: "string",
      description: "Export config for specific build from config file"
    })
    .option("all-builds", {
      type: "boolean",
      default: false,
      description: "Export all builds from config file"
    })
    .option("config-file", {
      type: "string",
      description:
        "Path to config file (default: config/shakapacker-builds.yml)"
    })
    // Validation Options
    .option("validate", {
      type: "boolean",
      default: false,
      description:
        "Validate all builds by running webpack/rspack (requires config file)"
    })
    .option("validate-build", {
      type: "string",
      description: "Validate specific build from config file"
    })
    // Troubleshooting
    .option("doctor", {
      type: "boolean",
      default: false,
      description:
        "Export all configs for troubleshooting (uses config file builds if available)"
    })
    // Output Options
    .option("save-dir", {
      type: "string",
      description:
        "Directory for output files (default: shakapacker-config-exports)"
    })
    .option("output", {
      type: "string",
      description: "Output to specific file instead of directory"
    })
    .option("stdout", {
      type: "boolean",
      default: false,
      description: "Output to stdout instead of saving to files"
    })
    .option("format", {
      type: "string",
      choices: ["yaml", "json", "inspect"] as const,
      description: "Output format (default: yaml for files, inspect for stdout)"
    })
    .option("annotate", {
      type: "boolean",
      description:
        "Enable inline documentation (YAML only, default with --doctor or file output)"
    })
    .option("depth", {
      type: "number",
      default: 20,
      coerce: (value: number | string) => {
        if (value === "null" || value === null) return null
        return typeof value === "number" ? value : parseInt(String(value), 10)
      },
      description: "Inspection depth (use 'null' for unlimited)"
    })
    .option("verbose", {
      type: "boolean",
      default: false,
      description: "Show full output without compact mode"
    })
    // Bundler Options
    .option("bundler", {
      type: "string",
      choices: ["webpack", "rspack"] as const,
      description: "Specify bundler (auto-detected if not provided)"
    })
    .option("webpack", {
      type: "boolean",
      default: false,
      description: "Use webpack (overrides config file)"
    })
    .option("rspack", {
      type: "boolean",
      default: false,
      description: "Use rspack (overrides config file)"
    })
    // Legacy/Fallback Options (when no config file exists)
    .option("env", {
      type: "string",
      choices: ["development", "production", "test"] as const,
      description:
        "Node environment (fallback when no config file exists, ignored with --doctor or --build)"
    })
    .option("client-only", {
      type: "boolean",
      default: false,
      description:
        "Generate only client config (fallback when no config file exists)"
    })
    .option("server-only", {
      type: "boolean",
      default: false,
      description:
        "Generate only server config (fallback when no config file exists)"
    })
    .check((argv) => {
      if (argv.webpack && argv.rspack) {
        throw new Error(
          "--webpack and --rspack are mutually exclusive. Please specify only one."
        )
      }
      if (argv["client-only"] && argv["server-only"]) {
        throw new Error(
          "--client-only and --server-only are mutually exclusive. Please specify only one."
        )
      }
      if (argv.output && argv["save-dir"]) {
        throw new Error(
          "--output and --save-dir are mutually exclusive. Use one or the other."
        )
      }
      if (argv.stdout && argv["save-dir"]) {
        throw new Error(
          "--stdout and --save-dir are mutually exclusive. Use one or the other."
        )
      }
      if (argv.build && argv["all-builds"]) {
        throw new Error(
          "--build and --all-builds are mutually exclusive. Use one or the other."
        )
      }
      if (argv.validate && argv["validate-build"]) {
        throw new Error(
          "--validate and --validate-build are mutually exclusive. Use one or the other."
        )
      }
      if (argv.validate && (argv.build || argv["all-builds"])) {
        throw new Error(
          "--validate cannot be used with --build or --all-builds."
        )
      }
      if (argv.ssr && !argv.init) {
        throw new Error(
          "--ssr can only be used with --init. Use: bin/shakapacker-config --init --ssr"
        )
      }
      return true
    })
    .help("help")
    .alias("help", "h")
    .epilogue(
      `Examples:

  # Config File Workflow (recommended)
  bin/shakapacker-config --init                           # Create config file
  bin/shakapacker-config --init --ssr                     # Create config with SSR builds
  bin/shakapacker-config --list-builds                    # List available builds
  bin/shakapacker-config --build=dev                      # Export specific build
  bin/shakapacker-config --all-builds --save-dir=./configs
  bin/shakapacker-config --build=dev --rspack             # Override bundler

  # Troubleshooting
  bin/shakapacker-config --doctor                         # Export all configs for debugging
  # If config file exists: exports all builds from config
  # If no config file: exports dev/prod client/server configs

  # Validate builds (requires config file)
  bin/shakapacker-config --validate                       # Validate all builds
  bin/shakapacker-config --validate-build=dev             # Validate specific build
  bin/shakapacker-config --validate --verbose             # Validate with full logs

  # Advanced output options
  bin/shakapacker-config --build=dev --stdout             # View in terminal
  bin/shakapacker-config --build=dev --output=config.yaml # Save to specific file`
    )
    .strict()
    .parseSync()

  // Type assertions are safe here because yargs validates choices at runtime
  // Handle --webpack and --rspack flags
  let bundler: "webpack" | "rspack" | undefined = argv.bundler as
    | "webpack"
    | "rspack"
    | undefined
  if (argv.webpack) bundler = "webpack"
  if (argv.rspack) bundler = "rspack"

  return {
    bundler,
    env: argv.env as "development" | "production" | "test" | undefined,
    clientOnly: argv["client-only"],
    serverOnly: argv["server-only"],
    output: argv.output,
    depth: argv.depth as number | null,
    format: argv.format as "yaml" | "json" | "inspect" | undefined,
    help: false, // yargs handles help internally
    verbose: argv.verbose,
    doctor: argv.doctor,
    saveDir: argv["save-dir"],
    stdout: argv.stdout,
    annotate: argv.annotate,
    init: argv.init,
    ssr: argv.ssr,
    configFile: argv["config-file"],
    build: argv.build,
    listBuilds: argv["list-builds"],
    allBuilds: argv["all-builds"],
    validate: argv.validate,
    validateBuild: argv["validate-build"]
  }
}

function applyDefaults(options: ExportOptions): ExportOptions {
  const updatedOptions = { ...options }

  if (updatedOptions.doctor) {
    if (updatedOptions.format === undefined) updatedOptions.format = "yaml"
    if (updatedOptions.annotate === undefined) updatedOptions.annotate = true
  } else if (!updatedOptions.stdout && !updatedOptions.output) {
    // Default mode: save to directory
    if (updatedOptions.format === undefined) updatedOptions.format = "yaml"
    if (updatedOptions.annotate === undefined) updatedOptions.annotate = true
  } else {
    if (updatedOptions.format === undefined) updatedOptions.format = "inspect"
    if (updatedOptions.annotate === undefined) updatedOptions.annotate = false
  }

  // Set default save directory for file output modes
  if (
    !updatedOptions.stdout &&
    !updatedOptions.output &&
    !updatedOptions.saveDir
  ) {
    updatedOptions.saveDir = resolve(
      process.cwd(),
      "shakapacker-config-exports"
    )
  }

  return updatedOptions
}

function runInitCommand(options: ExportOptions): number {
  const configPath = options.configFile || "config/shakapacker-builds.yml"
  const fullPath = resolve(process.cwd(), configPath)

  // Check if SSR variant is requested via --ssr flag
  const ssrMode = options.ssr || false

  if (existsSync(fullPath)) {
    console.error(
      `[Config Exporter] Error: Config file already exists: ${fullPath}`
    )
    console.error(
      `Remove it first or use --config-file=<path> for a different location.`
    )
    return 1
  }

  // Create bin stub if it doesn't exist
  const binStubPath = resolve(process.cwd(), "bin/shakapacker-config")
  const createdStub = !existsSync(binStubPath)
  if (createdStub) {
    createBinStub(binStubPath)
  }

  const sampleConfig = generateSampleConfigFile(ssrMode)
  writeFileSync(fullPath, sampleConfig, "utf8")

  console.log(`[Config Exporter] ✅ Created config file: ${fullPath}`)
  if (ssrMode) {
    console.log(
      `[Config Exporter] ℹ️  Generated SSR build configuration (5 builds)`
    )
  } else {
    console.log(
      `[Config Exporter] ℹ️  Generated standard build configuration (3 builds)`
    )
    console.log(
      `[Config Exporter] 💡 Uncomment SSR builds in the file if needed, or regenerate with: bin/shakapacker-config --init --ssr`
    )
  }

  if (createdStub) {
    console.log(`[Config Exporter] ✅ Created bin stub: ${binStubPath}`)
  }

  console.log(`\nNext steps:`)
  console.log(`  1. List available builds: bin/shakapacker --list-builds`)
  console.log(`  2. Run a build: bin/shakapacker --build <name>\n`)

  return 0
}

function createBinStub(binStubPath: string): void {
  const binDir = dirname(binStubPath)
  const { mkdirSync, chmodSync } = require("fs")

  // Ensure bin directory exists
  if (!existsSync(binDir)) {
    mkdirSync(binDir, { recursive: true })
  }

  const stubContent = `#!/usr/bin/env ruby
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= ENV["RACK_ENV"] || "development"
ENV["NODE_ENV"] ||= "development"

require "pathname"
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile",
  Pathname.new(__FILE__).realpath)

require "bundler/setup"

APP_ROOT = File.expand_path("..", __dir__)
Dir.chdir(APP_ROOT) do
  exec "node", "./node_modules/.bin/shakapacker-config", *ARGV
end
`

  writeFileSync(binStubPath, stubContent, { mode: 0o755 })

  // Make executable
  try {
    chmodSync(binStubPath, 0o755)
  } catch (e) {
    // chmod might fail on some systems, but mode in writeFileSync should handle it
  }
}

function runListBuildsCommand(options: ExportOptions): number {
  try {
    const loader = new ConfigFileLoader(options.configFile)
    loader.listBuilds()
    return 0
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error(`[Config Exporter] Error: ${errorMessage}`)
    return 1
  }
}

async function runValidateCommand(options: ExportOptions): Promise<number> {
  const savedEnv = saveBuildEnvironmentVariables()

  try {
    // Validate that config file exists
    const loader = new ConfigFileLoader(options.configFile)
    if (!loader.exists()) {
      const configPath = options.configFile || "config/shakapacker-builds.yml"
      throw new Error(
        `Config file ${configPath} not found. Run --init to create it.`
      )
    }

    // Set up environment
    const appRoot = findAppRoot()
    process.chdir(appRoot)
    setupNodePath(appRoot)

    const config = loader.load()
    const validator = new BuildValidator({ verbose: options.verbose || false })

    // Determine which builds to validate
    let buildsToValidate: string[]
    if (options.validateBuild) {
      // Validate specific build
      if (!config.builds[options.validateBuild]) {
        const available = Object.keys(config.builds).join(", ")
        throw new Error(
          `Build '${options.validateBuild}' not found in config file.\n` +
            `Available builds: ${available}`
        )
      }
      buildsToValidate = [options.validateBuild]
    } else {
      // Validate all builds
      buildsToValidate = Object.keys(config.builds)

      // Handle empty builds edge case
      if (buildsToValidate.length === 0) {
        throw new Error(
          `No builds found in config file. Add at least one build to config/shakapacker-builds.yml or run --init to see examples.`
        )
      }
    }

    console.log("\n" + "=".repeat(80))
    console.log("🔍 Validating Builds")
    console.log("=".repeat(80))
    console.log(`\nValidating ${buildsToValidate.length} build(s)...\n`)

    if (options.verbose) {
      console.log("⚡ VERBOSE MODE ENABLED - Full build output will be shown")
      console.log(
        "   This includes all webpack/rspack compilation logs, warnings, and progress messages"
      )
      console.log("   Use without --verbose to see only errors and summaries\n")
      console.log("=".repeat(80) + "\n")
    }

    const results = []

    // Validate each build
    for (const buildName of buildsToValidate) {
      if (options.verbose) {
        console.log("\n" + "=".repeat(80))
        console.log(`📦 VALIDATING BUILD: ${buildName}`)
        console.log("=".repeat(80))
      } else {
        console.log(`\n📦 Validating build: ${buildName}`)
      }

      // Clear and restore environment to prevent leakage between builds
      clearBuildEnvironmentVariables()
      restoreBuildEnvironmentVariables(savedEnv)

      // Get the build's environment to use for auto-detection
      const buildConfig = config.builds[buildName]
      const buildEnv =
        buildConfig.environment?.NODE_ENV ||
        (buildConfig.environment?.RAILS_ENV as
          | "development"
          | "production"
          | "test"
          | undefined) ||
        "development"

      // Auto-detect bundler using the build's environment
      const defaultBundler = await autoDetectBundler(buildEnv, appRoot)

      // Resolve build config with the correct default bundler
      const resolvedBuild = loader.resolveBuild(
        buildName,
        options,
        defaultBundler
      )

      // Validate the build
      const result = await validator.validateBuild(resolvedBuild, appRoot)
      results.push(result)

      // Show immediate feedback
      if (options.verbose) {
        console.log("=".repeat(80))
      }
      if (result.success) {
        console.log(`   ✅ Build passed`)
      } else {
        console.log(`   ❌ Build failed with ${result.errors.length} error(s)`)
      }
      if (options.verbose) {
        console.log("")
      }
    }

    // Print formatted results
    const formattedResults = validator.formatResults(results)
    console.log(formattedResults)

    // Return exit code based on results
    const hasFailures = results.some((r) => !r.success)
    return hasFailures ? 1 : 0
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error(`[Config Exporter] Error: ${errorMessage}`)
    return 1
  } finally {
    // Restore original environment
    restoreBuildEnvironmentVariables(savedEnv)
  }
}

async function runAllBuildsCommand(options: ExportOptions): Promise<number> {
  // Save original environment to restore after all builds
  const savedEnv = saveBuildEnvironmentVariables()

  try {
    // Set up environment
    const appRoot = findAppRoot()
    process.chdir(appRoot)
    setupNodePath(appRoot)

    // Apply defaults
    const resolvedOptions = applyDefaults(options)

    const loader = new ConfigFileLoader(resolvedOptions.configFile)
    if (!loader.exists()) {
      const configPath =
        resolvedOptions.configFile || "config/shakapacker-builds.yml"
      throw new Error(
        `Config file ${configPath} not found. Run --init to create it.`
      )
    }

    const config = loader.load()
    const buildNames = Object.keys(config.builds)

    console.log(
      `\n📦 Exporting ${buildNames.length} builds from config file...\n`
    )

    const targetDir = resolvedOptions.saveDir! // Set by applyDefaults
    const createdFiles: string[] = []

    // Export each build
    for (const buildName of buildNames) {
      console.log(`\n📦 Exporting build: ${buildName}`)

      // Clear and restore environment to prevent leakage between builds
      clearBuildEnvironmentVariables()
      restoreBuildEnvironmentVariables(savedEnv)

      // Create a modified options object for this build
      const buildOptions = { ...resolvedOptions, build: buildName }
      const configs = await loadConfigsForEnv(undefined, buildOptions, appRoot)

      for (const { config: cfg, metadata } of configs) {
        const output = formatConfig(cfg, metadata, resolvedOptions, appRoot)
        const filename = FileWriter.generateFilename(
          metadata.bundler,
          metadata.environment,
          metadata.configType,
          resolvedOptions.format!,
          metadata.buildName
        )

        const fullPath = resolve(targetDir, filename)
        FileWriter.writeSingleFile(fullPath, output)
        createdFiles.push(fullPath)
      }
    }

    // Print summary
    console.log("\n" + "=".repeat(80))
    console.log("✅ All Builds Exported!")
    console.log("=".repeat(80))
    console.log(`\nCreated ${createdFiles.length} configuration file(s) in:`)
    console.log(`  ${targetDir}\n`)
    console.log("Files:")
    createdFiles.forEach((file) => {
      console.log(`  ✓ ${basename(file)}`)
    })
    console.log("\n" + "=".repeat(80) + "\n")

    return 0
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error)
    console.error(`[Config Exporter] Error: ${errorMessage}`)
    return 1
  } finally {
    // Restore original environment
    restoreBuildEnvironmentVariables(savedEnv)
  }
}

async function runDoctorMode(
  options: ExportOptions,
  appRoot: string
): Promise<void> {
  // Save original environment to restore after all builds
  const savedEnv = saveBuildEnvironmentVariables()

  try {
    console.log("\n" + "=".repeat(80))
    console.log("🔍 Config Exporter - Doctor Mode")
    console.log("=".repeat(80))

    const targetDir = options.saveDir! // Set by applyDefaults

    const createdFiles: string[] = []

    // Check if config file exists - always use it for doctor mode
    const configFilePath = options.configFile || "config/shakapacker-builds.yml"
    const loader = new ConfigFileLoader(configFilePath)

    if (loader.exists()) {
      try {
        const configData = loader.load()
        console.log(`\nUsing builds from ${configFilePath}...\n`)

        // Use config file builds
        const buildNames = Object.keys(configData.builds)

        for (const buildName of buildNames) {
          console.log(`\n📦 Loading build: ${buildName}`)

          // Clear and restore environment to prevent leakage between builds
          clearBuildEnvironmentVariables()
          restoreBuildEnvironmentVariables(savedEnv)

          const configs = await loadConfigsForEnv(
            undefined,
            { ...options, build: buildName },
            appRoot
          )

          for (const { config, metadata } of configs) {
            const output = formatConfig(config, metadata, options, appRoot)
            const filename = FileWriter.generateFilename(
              metadata.bundler,
              metadata.environment,
              metadata.configType,
              options.format!,
              metadata.buildName
            )
            const fullPath = resolve(targetDir, filename)
            FileWriter.writeSingleFile(fullPath, output)
            createdFiles.push(fullPath)
          }
        }

        // Print summary and exit early
        printDoctorSummary(createdFiles, targetDir)
        return
      } catch (error: unknown) {
        // If config file exists but is invalid, show error and exit
        const errorMessage =
          error instanceof Error ? error.message : String(error)
        console.error(`\n❌ Config file found but invalid: ${errorMessage}`)
        console.error(
          `Fix the config file or run: bin/shakapacker-config --init\n`
        )
        throw error
      }
    }

    // No config file found - suggest creating one
    console.log(`\n⚠️  No build config file found at ${configFilePath}`)
    console.log(`Run: bin/shakapacker-config --init to create one.\n`)
    console.log("Exporting default development and production configs...")
    console.log("")

    const configsToExport = [
      { label: "development (HMR)", env: "development" as const, hmr: true },
      { label: "development", env: "development" as const, hmr: false },
      { label: "production", env: "production" as const, hmr: false }
    ]

    for (const { label, env, hmr } of configsToExport) {
      console.log(`\n📦 Loading ${label} configuration...`)

      // Clear and restore environment to prevent leakage between builds
      clearBuildEnvironmentVariables()
      restoreBuildEnvironmentVariables(savedEnv)

      // Set WEBPACK_SERVE for HMR config
      if (hmr) {
        process.env.WEBPACK_SERVE = "true"
      }

      const configs = await loadConfigsForEnv(env, options, appRoot)

      for (const { config, metadata } of configs) {
        const output = formatConfig(config, metadata, options, appRoot)

        // Adjust filename for HMR config
        let filename: string
        if (
          hmr &&
          (metadata.configType === "client" || metadata.configType === "all")
        ) {
          /**
           * HMR Mode Filename Logic:
           * - When WEBPACK_SERVE=true, webpack-dev-server runs and HMR is enabled
           * - HMR only applies to client bundles (server bundles don't use HMR)
           * - If configType is "all", we still only generate client file for HMR
           *   because the server bundle is identical to non-HMR development
           * - Filename uses "client" type and "development-hmr" build name to
           *   distinguish it from regular development client bundle
           */
          filename = FileWriter.generateFilename(
            metadata.bundler,
            metadata.environment,
            "client",
            options.format!,
            "development-hmr"
          )
        } else {
          filename = FileWriter.generateFilename(
            metadata.bundler,
            metadata.environment,
            metadata.configType,
            options.format!,
            metadata.buildName
          )
        }

        const fullPath = resolve(targetDir, filename)
        const fileOutput: FileOutput = { filename, content: output, metadata }
        FileWriter.writeSingleFile(fullPath, output)
        createdFiles.push(fullPath)
      }
    }

    printDoctorSummary(createdFiles, targetDir)
  } finally {
    // Restore original environment
    restoreBuildEnvironmentVariables(savedEnv)
  }
}

function printDoctorSummary(createdFiles: string[], targetDir: string): void {
  // Print summary
  console.log("\n" + "=".repeat(80))
  console.log("✅ Export Complete!")
  console.log("=".repeat(80))
  console.log(`\nCreated ${createdFiles.length} configuration file(s) in:`)
  console.log(`  ${targetDir}\n`)
  console.log("Files:")
  createdFiles.forEach((file) => {
    console.log(`  ✓ ${basename(file)}`)
  })

  // Check if directory should be added to .gitignore
  const gitignorePath = resolve(process.cwd(), ".gitignore")
  const dirName = basename(targetDir)
  let shouldSuggestGitignore = false

  if (existsSync(gitignorePath)) {
    const gitignoreContent = readFileSync(gitignorePath, "utf8")
    if (!gitignoreContent.includes(dirName)) {
      shouldSuggestGitignore = true
    }
  }

  if (shouldSuggestGitignore) {
    console.log("\n" + "─".repeat(80))
    console.log(
      "💡 Tip: Add the export directory to .gitignore to avoid committing config files:"
    )
    console.log(`\n  echo "${dirName}/" >> .gitignore\n`)
  }

  console.log("\n" + "=".repeat(80) + "\n")
}

async function runSaveMode(
  options: ExportOptions,
  appRoot: string
): Promise<void> {
  const env = options.env || "development"
  console.log(`[Config Exporter] Exporting ${env} configs`)

  const targetDir = options.saveDir! // Set by applyDefaults
  const configs = await loadConfigsForEnv(options.env, options, appRoot)
  const createdFiles: string[] = []

  if (options.output) {
    // Single file output
    const combined = configs.map((c) => c.config)
    const metadata = configs[0].metadata
    metadata.configCount = combined.length

    const output = formatConfig(
      combined.length === 1 ? combined[0] : combined,
      metadata,
      options,
      appRoot
    )
    const fullPath = resolve(options.output)
    FileWriter.writeSingleFile(fullPath, output)
    createdFiles.push(fullPath)
  } else {
    // Multi-file output (one per config)
    for (const { config, metadata } of configs) {
      const output = formatConfig(config, metadata, options, appRoot)
      const filename = FileWriter.generateFilename(
        metadata.bundler,
        metadata.environment,
        metadata.configType,
        options.format!,
        metadata.buildName
      )
      const fullPath = resolve(targetDir, filename)
      FileWriter.writeSingleFile(fullPath, output)
      createdFiles.push(fullPath)
    }
  }

  // Log all created files
  console.log(`\n[Config Exporter] Created ${createdFiles.length} file(s):`)
  createdFiles.forEach((file) => {
    console.log(`  ✓ ${file}`)
  })
}

async function runStdoutMode(
  options: ExportOptions,
  appRoot: string
): Promise<void> {
  const configs = await loadConfigsForEnv(options.env!, options, appRoot)
  const combined = configs.map((c) => c.config)
  const metadata = configs[0].metadata
  metadata.configCount = combined.length

  const config = combined.length === 1 ? combined[0] : combined
  const output = formatConfig(config, metadata, options, appRoot)

  console.log("\n" + "=".repeat(80) + "\n")
  console.log(output)
}

async function runSingleFileMode(
  options: ExportOptions,
  appRoot: string
): Promise<void> {
  const configs = await loadConfigsForEnv(options.env!, options, appRoot)
  const combined = configs.map((c) => c.config)
  const metadata = configs[0].metadata
  metadata.configCount = combined.length

  const config = combined.length === 1 ? combined[0] : combined
  const output = formatConfig(config, metadata, options, appRoot)

  const filePath = resolve(process.cwd(), options.output!)
  FileWriter.writeSingleFile(filePath, output)
}

async function loadConfigsForEnv(
  env: "development" | "production" | "test" | undefined,
  options: ExportOptions,
  appRoot: string
): Promise<Array<{ config: any; metadata: ConfigMetadata }>> {
  let bundler: "webpack" | "rspack"
  let buildName: string | undefined
  let buildOutputs: string[] = []
  let customConfigFile: string | undefined
  let bundlerEnvArgs: string[] = []
  let finalEnv: "development" | "production" | "test"

  // If using config file build
  if (options.build) {
    // Use a temporary env for auto-detection, will be overridden by build config
    const tempEnv = env || "development"
    const loader = new ConfigFileLoader(options.configFile)
    const defaultBundler = await autoDetectBundler(tempEnv, appRoot)
    const resolvedBuild = loader.resolveBuild(
      options.build,
      options,
      defaultBundler
    )

    bundler = resolvedBuild.bundler
    buildName = resolvedBuild.name
    buildOutputs = resolvedBuild.outputs
    customConfigFile = resolvedBuild.configFile
    bundlerEnvArgs = resolvedBuild.bundlerEnvArgs

    // Set environment variables from config
    // Security: Only allow specific environment variables to prevent malicious configs
    const DANGEROUS_ENV_VARS = [
      "PATH",
      "HOME",
      "LD_PRELOAD",
      "LD_LIBRARY_PATH",
      "DYLD_LIBRARY_PATH",
      "DYLD_INSERT_LIBRARIES"
    ]

    for (const [key, value] of Object.entries(resolvedBuild.environment)) {
      if (DANGEROUS_ENV_VARS.includes(key)) {
        console.warn(
          `[Config Exporter] Warning: Skipping dangerous environment variable: ${key}`
        )
        continue
      }
      if (!(BUILD_ENV_VARS as readonly string[]).includes(key)) {
        console.warn(
          `[Config Exporter] Warning: Skipping non-whitelisted environment variable: ${key}. ` +
            `Allowed variables are: ${BUILD_ENV_VARS.join(", ")}`
        )
        continue
      }
      process.env[key] = value
    }

    // Determine final env: CLI flag > build config NODE_ENV > default
    if (options.env) {
      finalEnv = options.env
    } else if (resolvedBuild.environment.NODE_ENV) {
      const nodeEnv = resolvedBuild.environment.NODE_ENV
      const allowedEnvs = ["development", "production", "test"]
      if (allowedEnvs.includes(nodeEnv)) {
        finalEnv = nodeEnv as "development" | "production" | "test"
      } else {
        throw new Error(
          `Invalid NODE_ENV value in config: "${nodeEnv}". ` +
            `Allowed values are: ${allowedEnvs.join(", ")}.`
        )
      }
    } else {
      finalEnv = "development"
    }

    // Sync process.env to reflect resolved environment
    process.env.NODE_ENV = finalEnv
    // Determine RAILS_ENV: CLI env option > build config RAILS_ENV > finalEnv
    const railsEnv =
      options.env || resolvedBuild.environment.RAILS_ENV || finalEnv
    process.env.RAILS_ENV = railsEnv
  } else {
    // No build config - use CLI env or default
    finalEnv = env || "development"

    // Auto-detect bundler if not specified
    bundler = options.bundler || (await autoDetectBundler(finalEnv, appRoot))

    // Set environment variables
    process.env.NODE_ENV = finalEnv
    process.env.RAILS_ENV = finalEnv
  }

  if (options.clientOnly) {
    process.env.CLIENT_BUNDLE_ONLY = "yes"
  } else if (options.serverOnly) {
    process.env.SERVER_BUNDLE_ONLY = "yes"
  }

  // Find and load config file
  const configFile =
    customConfigFile || findConfigFile(bundler, appRoot, finalEnv)
  // Quiet mode for cleaner output - only show if verbose or errors
  if (process.env.VERBOSE) {
    console.log(`[Config Exporter] Loading config: ${configFile}`)
    console.log(`[Config Exporter] Environment: ${finalEnv}`)
    console.log(`[Config Exporter] Bundler: ${bundler}`)
    if (buildName) {
      console.log(`[Config Exporter] Build: ${buildName}`)
    }
  }

  // Load the config
  // Register ts-node for TypeScript config files
  if (configFile.endsWith(".ts")) {
    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      require("ts-node/register/transpile-only")
    } catch (error) {
      throw new Error(
        "TypeScript config detected but ts-node is not available. " +
          "Install ts-node as a dev dependency: npm install --save-dev ts-node"
      )
    }
  }

  // Clear require cache for config file and all related modules
  /**
   * AGGRESSIVE REQUIRE CACHE CLEARING
   *
   * Why: This tool can load multiple environments (dev/prod) and builds in a
   * single process. Node's require cache prevents modules from re-evaluating,
   * which causes stale environment values (NODE_ENV, etc.) to persist.
   *
   * What: Clears cache for:
   * - Webpack/rspack config files (they read process.env)
   * - Shakapacker modules (env detection, config loading)
   * - Config directory files (custom helpers that may read env)
   *
   * Trade-offs:
   * - More reliable: Ensures each build gets fresh environment
   * - Potentially brittle: String matching on paths (but comprehensive)
   * - Performance: Minimal impact since this runs per-build, not per-file
   *
   * Maintenance: If adding new shakapacker modules that read env vars,
   * ensure their paths are covered by the patterns below.
   */
  const configDir = dirname(configFile)
  Object.keys(require.cache).forEach((key) => {
    if (
      key.includes("webpack.config") ||
      key.includes("rspack.config") ||
      key.startsWith(configDir) ||
      key.includes("/shakapacker/") || // npm installed shakapacker
      key.includes("\\shakapacker\\") || // Windows path
      key.includes("/package/env") || // shakapacker env module (local dev)
      key.includes("\\package\\env") || // Windows env module
      key.includes("/package/index") || // shakapacker main module
      key.includes("\\package\\index") || // Windows main module
      key === configFile
    ) {
      delete require.cache[key]
    }
  })

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  let loadedConfig = require(configFile)

  // Handle ES module default export
  if (typeof loadedConfig === "object" && "default" in loadedConfig) {
    loadedConfig = loadedConfig.default
  }

  // Handle function exports (webpack config functions)
  if (typeof loadedConfig === "function") {
    // Webpack config functions receive (env, argv) parameters
    // Build env object from bundler_env args if available
    const envObject: Record<string, any> = {}
    if (bundlerEnvArgs && bundlerEnvArgs.length > 0) {
      // Parse --env key=value or --env key into object
      for (let i = 0; i < bundlerEnvArgs.length; i += 2) {
        if (bundlerEnvArgs[i] === "--env") {
          const envArg = bundlerEnvArgs[i + 1]
          if (envArg.includes("=")) {
            const [key, value] = envArg.split("=")
            envObject[key] = value
          } else {
            envObject[envArg] = true
          }
        }
      }
    }

    const argv = { mode: finalEnv }
    try {
      loadedConfig = loadedConfig(envObject, argv)
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : String(error)
      throw new Error(
        `Failed to execute config function: ${errorMessage}\n` +
          `Config file: ${configFile}\n` +
          `Environment: ${JSON.stringify(envObject)}`
      )
    }
  }

  // Determine config type and split if array
  const configs: any[] = Array.isArray(loadedConfig)
    ? loadedConfig
    : [loadedConfig]
  const results: Array<{ config: any; metadata: ConfigMetadata }> = []

  configs.forEach((cfg, index) => {
    let configType: "client" | "server" | "all" = "all"

    // Use outputs from build config if available
    if (
      buildOutputs.length > 0 &&
      index < buildOutputs.length &&
      buildOutputs[index]
    ) {
      const outputValue = buildOutputs[index]
      // Validate the output value is a valid config type
      if (
        outputValue === "client" ||
        outputValue === "server" ||
        outputValue === "all"
      ) {
        configType = outputValue
      } else {
        throw new Error(
          `Invalid output type '${outputValue}' at index ${index} in build '${buildName}'. ` +
            `Allowed values are: client, server, all`
        )
      }
    } else if (configs.length === 2) {
      // Likely client and server configs
      configType = index === 0 ? "client" : "server"
    } else if (options.clientOnly) {
      configType = "client"
    } else if (options.serverOnly) {
      configType = "server"
    }

    const metadata: ConfigMetadata = {
      exportedAt: new Date().toISOString(),
      bundler,
      environment: finalEnv,
      configFile,
      configType,
      configCount: configs.length,
      buildName,
      environmentVariables: {
        NODE_ENV: process.env.NODE_ENV,
        RAILS_ENV: process.env.RAILS_ENV,
        CLIENT_BUNDLE_ONLY: process.env.CLIENT_BUNDLE_ONLY,
        SERVER_BUNDLE_ONLY: process.env.SERVER_BUNDLE_ONLY,
        WEBPACK_SERVE: process.env.WEBPACK_SERVE
      }
    }

    // Clean config if not verbose
    let cleanedConfig = cfg
    if (!options.verbose) {
      cleanedConfig = cleanConfig(cfg, appRoot)
    }

    results.push({ config: cleanedConfig, metadata })
  })

  return results
}

function formatConfig(
  config: any,
  metadata: ConfigMetadata,
  options: ExportOptions,
  appRoot: string
): string {
  if (options.format === "yaml") {
    const serializer = new YamlSerializer({
      annotate: options.annotate!,
      appRoot
    })
    return serializer.serialize(config, metadata)
  }
  if (options.format === "json") {
    const jsonReplacer = (key: string, value: any): any => {
      if (typeof value === "function") {
        return `[Function: ${value.name || "anonymous"}]`
      }
      if (value instanceof RegExp) {
        return `[RegExp: ${value.toString()}]`
      }
      if (
        value &&
        typeof value === "object" &&
        value.constructor &&
        value.constructor.name !== "Object" &&
        value.constructor.name !== "Array"
      ) {
        return `[${value.constructor.name}]`
      }
      return value
    }
    return JSON.stringify({ metadata, config }, jsonReplacer, 2)
  } else {
    // inspect format
    const inspectOptions = {
      depth: options.depth,
      colors: false,
      maxArrayLength: null,
      maxStringLength: null,
      breakLength: 120,
      compact: false
    }

    let output =
      "=== METADATA ===\n\n" + inspect(metadata, inspectOptions) + "\n\n"
    output += "=== CONFIG ===\n\n"

    if (Array.isArray(config)) {
      output += `Total configs: ${config.length}\n\n`
      config.forEach((cfg, index) => {
        output += `--- Config [${index}] ---\n\n`
        output += inspect(cfg, inspectOptions) + "\n\n"
      })
    } else {
      output += inspect(config, inspectOptions) + "\n"
    }

    return output
  }
}

function cleanConfig(obj: any, rootPath: string): any {
  const makePathRelative = (str: string): string => {
    if (typeof str === "string" && str.startsWith(rootPath)) {
      return "./" + str.substring(rootPath.length + 1)
    }
    return str
  }

  function clean(value: any, key?: string, parent?: any): any {
    // Remove EnvironmentPlugin keys and defaultValues
    if (
      parent &&
      parent.constructor &&
      parent.constructor.name === "EnvironmentPlugin"
    ) {
      if (key === "keys" || key === "defaultValues") {
        return undefined
      }
    }

    if (typeof value === "function") {
      // Show function source
      const source = value.toString()
      const compacted = source
        .split("\n")
        .map((line: string) => line.trim())
        .filter((line: string) => line.length > 0)
        .join(" ")
      return compacted
    }

    if (typeof value === "string") {
      return makePathRelative(value)
    }

    if (Array.isArray(value)) {
      return value
        .map((item, i) => clean(item, String(i), value))
        .filter((v) => v !== undefined)
    }

    if (value && typeof value === "object") {
      const cleaned: any = {}
      for (const k in value) {
        if (Object.prototype.hasOwnProperty.call(value, k)) {
          const cleanedValue = clean(value[k], k, value)
          if (cleanedValue !== undefined) {
            cleaned[k] = cleanedValue
          }
        }
      }
      return cleaned
    }

    return value
  }

  return clean(obj)
}

/**
 * Loads and returns shakapacker.yml configuration
 */
function loadShakapackerConfig(
  env: string,
  appRoot: string
): { bundler: "webpack" | "rspack"; configPath: string } {
  try {
    const configFilePath =
      process.env.SHAKAPACKER_CONFIG ||
      resolve(appRoot, "config/shakapacker.yml")

    if (existsSync(configFilePath)) {
      const config: any = loadYaml(readFileSync(configFilePath, "utf8"))
      const envConfig = config[env] || config.default || {}

      // Get bundler
      const bundler = envConfig.assets_bundler || "webpack"
      if (bundler !== "webpack" && bundler !== "rspack") {
        console.warn(
          `[Config Exporter] Invalid bundler '${bundler}' in shakapacker.yml, defaulting to webpack`
        )
        return {
          bundler: "webpack",
          configPath: bundler === "rspack" ? "config/rspack" : "config/webpack"
        }
      }

      // Get config path
      const customConfigPath = envConfig.assets_bundler_config_path
      const configPath =
        customConfigPath ||
        (bundler === "rspack" ? "config/rspack" : "config/webpack")

      console.log(
        `[Config Exporter] Auto-detected bundler: ${bundler}, config path: ${configPath}`
      )
      return { bundler, configPath }
    }
  } catch (error: unknown) {
    console.warn(
      `[Config Exporter] Error loading shakapacker config, defaulting to webpack`
    )
  }

  return { bundler: "webpack", configPath: "config/webpack" }
}

/**
 * Auto-detects bundler from shakapacker.yml
 *
 * Error Handling Strategy:
 * - Invalid bundler → warns and defaults to webpack (graceful fallback)
 * - Config read errors → warns and defaults to webpack (graceful fallback)
 *
 * Rationale for warnings vs errors:
 * - This reads shakapacker.yml (infrastructure config), not user build config
 * - Failures here should not block the tool; defaulting to webpack is safe
 * - Contrast with NODE_ENV validation in build configs, which throws errors
 *   because invalid NODE_ENV would produce incorrect builds
 */
async function autoDetectBundler(
  env: string,
  appRoot: string
): Promise<"webpack" | "rspack"> {
  const { bundler } = loadShakapackerConfig(env, appRoot)
  return bundler
}

function findConfigFile(
  bundler: "webpack" | "rspack",
  appRoot: string,
  env: string
): string {
  const { configPath } = loadShakapackerConfig(env, appRoot)
  const extensions = ["ts", "js"]

  if (bundler === "rspack") {
    for (const ext of extensions) {
      const rspackPath = resolve(appRoot, configPath, `rspack.config.${ext}`)
      if (existsSync(rspackPath)) {
        return rspackPath
      }
    }
  }

  // Fall back to webpack config
  for (const ext of extensions) {
    const webpackPath = resolve(appRoot, configPath, `webpack.config.${ext}`)
    if (existsSync(webpackPath)) {
      return webpackPath
    }
  }

  throw new Error(
    `Could not find ${bundler} config file. Expected: ${configPath}/${bundler}.config.{js,ts}`
  )
}

function findAppRoot(): string {
  let currentDir = process.cwd()
  const root = dirname(currentDir).split(sep)[0] + sep

  while (currentDir !== root && currentDir !== dirname(currentDir)) {
    if (
      existsSync(resolve(currentDir, "package.json")) ||
      existsSync(resolve(currentDir, "config/shakapacker.yml"))
    ) {
      return currentDir
    }
    currentDir = dirname(currentDir)
  }

  return process.cwd()
}

function setupNodePath(appRoot: string): void {
  const nodePaths = [
    resolve(appRoot, "node_modules"),
    resolve(appRoot, "..", "..", "node_modules"),
    resolve(appRoot, "..", "..", "package"),
    ...(appRoot.includes("/spec/dummy")
      ? [resolve(appRoot, "../../node_modules")]
      : [])
  ].filter((p) => existsSync(p))

  if (nodePaths.length > 0) {
    const existingNodePath = process.env.NODE_PATH || ""
    process.env.NODE_PATH = existingNodePath
      ? `${nodePaths.join(delimiter)}${delimiter}${existingNodePath}`
      : nodePaths.join(delimiter)

    // eslint-disable-next-line @typescript-eslint/no-var-requires
    require("module").Module._initPaths()
  }
}
