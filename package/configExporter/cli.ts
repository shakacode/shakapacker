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

    // Handle --all-builds command
    if (options.allBuilds) {
      return runAllBuildsCommand(options)
    }

    // Set up environment
    const appRoot = findAppRoot()
    process.chdir(appRoot)
    setupNodePath(appRoot)

    // Apply defaults
    applyDefaults(options)

    // Validate after defaults are applied
    if (options.annotate && options.format !== "yaml") {
      throw new Error(
        "Annotation requires YAML format. Use --no-annotate or --format=yaml."
      )
    }

    // Validate --build requires config file
    if (options.build) {
      const loader = new ConfigFileLoader(options.configFile)
      if (!loader.exists()) {
        const configPath = options.configFile || ".bundler-config.yml"
        throw new Error(
          `--build requires a config file but ${configPath} not found. Run --init to create it.`
        )
      }
    }

    // Execute based on mode
    if (options.doctor) {
      await runDoctorMode(options, appRoot)
    } else if (options.stdout || options.output) {
      // Explicit stdout mode or single file output
      await runStdoutMode(options, appRoot)
    } else {
      // Default: save to directory
      await runSaveMode(options, appRoot)
    }

    return 0
  } catch (error: any) {
    console.error(`[Config Exporter] Error: ${error.message}`)
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
  bin/export-bundler-config --doctor

  Exports annotated YAML configs for both development and production.
  Creates separate files for client and server bundles.
  Best for debugging, AI analysis, and comparing configurations.`
    )
    .option("doctor", {
      type: "boolean",
      default: false,
      description:
        "Export all configs for troubleshooting (dev + prod, annotated YAML)"
    })
    .option("save-dir", {
      type: "string",
      description:
        "Directory for output files (default: shakapacker-config-exports)"
    })
    .option("stdout", {
      type: "boolean",
      default: false,
      description: "Output to stdout instead of saving to files"
    })
    .option("bundler", {
      type: "string",
      choices: ["webpack", "rspack"] as const,
      description: "Specify bundler (auto-detected if not provided)"
    })
    .option("env", {
      type: "string",
      choices: ["development", "production", "test"] as const,
      description:
        "Node environment (default: development, ignored with --doctor or --build)"
    })
    .option("client-only", {
      type: "boolean",
      default: false,
      description: "Generate only client config (sets CLIENT_BUNDLE_ONLY=yes)"
    })
    .option("server-only", {
      type: "boolean",
      default: false,
      description: "Generate only server config (sets SERVER_BUNDLE_ONLY=yes)"
    })
    .option("output", {
      type: "string",
      description: "Output to specific file instead of directory"
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
    .option("verbose", {
      type: "boolean",
      default: false,
      description: "Show full output without compact mode"
    })
    .option("init", {
      type: "boolean",
      default: false,
      description: "Generate sample .bundler-config.yml with examples"
    })
    .option("config-file", {
      type: "string",
      description: "Path to config file (default: .bundler-config.yml)"
    })
    .option("build", {
      type: "string",
      description: "Export config for specific build from config file"
    })
    .option("list-builds", {
      type: "boolean",
      default: false,
      description: "List all available builds from config file"
    })
    .option("all-builds", {
      type: "boolean",
      default: false,
      description: "Export all builds from config file"
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
      return true
    })
    .help("help")
    .alias("help", "h")
    .epilogue(
      `Examples:

  # Config File Workflow
  bin/export-bundler-config --init
  bin/export-bundler-config --list-builds
  bin/export-bundler-config --build=dev
  bin/export-bundler-config --all-builds --save-dir=./configs
  bin/export-bundler-config --build=dev --rspack

  # Traditional Workflow (without config file)
  bin/export-bundler-config --doctor
  bin/export-bundler-config --env=production --client-only
  bin/export-bundler-config --save-dir=./debug
  bin/export-bundler-config                               # Saves to shakapacker-config-exports/

  # View config in terminal (stdout)
  bin/export-bundler-config --stdout
  bin/export-bundler-config --output=config.yaml          # Save to specific file`
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
    configFile: argv["config-file"],
    build: argv.build,
    listBuilds: argv["list-builds"],
    allBuilds: argv["all-builds"]
  }
}

function applyDefaults(options: ExportOptions): void {
  if (options.doctor) {
    if (options.format === undefined) options.format = "yaml"
    if (options.annotate === undefined) options.annotate = true
  } else if (!options.stdout && !options.output) {
    // Default mode: save to directory
    if (options.format === undefined) options.format = "yaml"
    if (options.annotate === undefined) options.annotate = true
  } else {
    if (options.format === undefined) options.format = "inspect"
    if (options.annotate === undefined) options.annotate = false
  }
}

function runInitCommand(options: ExportOptions): number {
  const configPath = options.configFile || ".bundler-config.yml"
  const fullPath = resolve(process.cwd(), configPath)

  if (existsSync(fullPath)) {
    console.error(
      `[Config Exporter] Error: Config file already exists: ${fullPath}`
    )
    console.error(
      `Remove it first or use --config-file=<path> for a different location.`
    )
    return 1
  }

  const sampleConfig = generateSampleConfigFile()
  writeFileSync(fullPath, sampleConfig, "utf8")

  console.log(`[Config Exporter] ✅ Created config file: ${fullPath}`)
  console.log(`\nNext steps:`)
  console.log(`  1. Edit the config file to match your build setup`)
  console.log(
    `  2. List available builds: bin/export-bundler-config --list-builds`
  )
  console.log(
    `  3. Export a build: bin/export-bundler-config --build=<name> --save\n`
  )

  return 0
}

function runListBuildsCommand(options: ExportOptions): number {
  try {
    const loader = new ConfigFileLoader(options.configFile)
    loader.listBuilds()
    return 0
  } catch (error: any) {
    console.error(`[Config Exporter] Error: ${error.message}`)
    return 1
  }
}

async function runAllBuildsCommand(options: ExportOptions): Promise<number> {
  try {
    // Set up environment
    const appRoot = findAppRoot()
    process.chdir(appRoot)
    setupNodePath(appRoot)

    // Apply defaults
    applyDefaults(options)

    const loader = new ConfigFileLoader(options.configFile)
    if (!loader.exists()) {
      const configPath = options.configFile || ".bundler-config.yml"
      throw new Error(
        `Config file ${configPath} not found. Run --init to create it.`
      )
    }

    const config = loader.load()
    const buildNames = Object.keys(config.builds)

    console.log(
      `\n📦 Exporting ${buildNames.length} builds from config file...\n`
    )

    const fileWriter = new FileWriter()
    const defaultDir = resolve(process.cwd(), "shakapacker-config-exports")
    const targetDir = options.saveDir || defaultDir
    const createdFiles: string[] = []

    // Export each build
    for (const buildName of buildNames) {
      console.log(`\n📦 Exporting build: ${buildName}`)

      // Clear environment variables to prevent leakage between builds
      clearBuildEnvironmentVariables()

      // Create a modified options object for this build
      const buildOptions = { ...options, build: buildName }
      const configs = await loadConfigsForEnv(undefined, buildOptions, appRoot)

      for (const { config: cfg, metadata } of configs) {
        const output = formatConfig(cfg, metadata, options, appRoot)
        const filename = fileWriter.generateFilename(
          metadata.bundler,
          metadata.environment,
          metadata.configType,
          options.format!,
          metadata.buildName
        )

        const fullPath = resolve(targetDir, filename)
        fileWriter.writeSingleFile(fullPath, output, true) // quiet mode
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
  } catch (error: any) {
    console.error(`[Config Exporter] Error: ${error.message}`)
    return 1
  }
}

async function runDoctorMode(
  options: ExportOptions,
  appRoot: string
): Promise<void> {
  console.log("\n" + "=".repeat(80))
  console.log("🔍 Config Exporter - Doctor Mode")
  console.log("=".repeat(80))

  const fileWriter = new FileWriter()
  const defaultDir = resolve(process.cwd(), "shakapacker-config-exports")
  const targetDir = options.saveDir || defaultDir

  const createdFiles: string[] = []

  // Check if config file exists with shakapacker_default_builds flag
  const configFilePath = options.configFile || ".bundler-config.yml"
  const loader = new ConfigFileLoader(configFilePath)

  if (loader.exists()) {
    try {
      const configData = loader.load()
      if (configData.shakapacker_default_builds) {
        console.log(
          "\nUsing builds from config file (shakapacker_default_builds: true)...\n"
        )
        // Use config file builds
        const buildNames = Object.keys(configData.builds)

        for (const buildName of buildNames) {
          console.log(`\n📦 Loading build: ${buildName}`)

          // Clear environment variables to prevent leakage between builds
          clearBuildEnvironmentVariables()

          const configs = await loadConfigsForEnv(
            undefined,
            { ...options, build: buildName },
            appRoot
          )

          for (const { config, metadata } of configs) {
            const output = formatConfig(config, metadata, options, appRoot)
            const filename = fileWriter.generateFilename(
              metadata.bundler,
              metadata.environment,
              metadata.configType,
              options.format!,
              metadata.buildName
            )
            const fullPath = resolve(targetDir, filename)
            fileWriter.writeSingleFile(fullPath, output, true) // quiet mode
            createdFiles.push(fullPath)
          }
        }

        // Print summary and exit early
        printDoctorSummary(createdFiles, targetDir)
        return
      }
    } catch (error: any) {
      // If config file exists but is invalid, warn and fall through to default behavior
      console.log(`\n⚠️  Config file found but invalid: ${error.message}`)
      console.log("Falling back to default doctor mode...\n")
    }
  }

  // Default behavior: hardcoded configs
  console.log("\nExporting all development and production configs...")
  console.log("")

  const configsToExport = [
    { label: "development (HMR)", env: "development" as const, hmr: true },
    { label: "development", env: "development" as const, hmr: false },
    { label: "production", env: "production" as const, hmr: false }
  ]

  for (const { label, env, hmr } of configsToExport) {
    console.log(`\n📦 Loading ${label} configuration...`)

    // Set WEBPACK_SERVE for HMR config
    const originalWebpackServe = process.env.WEBPACK_SERVE
    if (hmr) {
      process.env.WEBPACK_SERVE = "true"
    }

    const configs = await loadConfigsForEnv(env, options, appRoot)

    // Restore original WEBPACK_SERVE
    if (hmr) {
      if (originalWebpackServe) {
        process.env.WEBPACK_SERVE = originalWebpackServe
      } else {
        delete process.env.WEBPACK_SERVE
      }
    }

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
        filename = fileWriter.generateFilename(
          metadata.bundler,
          metadata.environment,
          "client",
          options.format!,
          "development-hmr"
        )
      } else {
        filename = fileWriter.generateFilename(
          metadata.bundler,
          metadata.environment,
          metadata.configType,
          options.format!,
          metadata.buildName
        )
      }

      const fullPath = resolve(targetDir, filename)
      const fileOutput: FileOutput = { filename, content: output, metadata }
      fileWriter.writeSingleFile(fullPath, output, true) // quiet mode
      createdFiles.push(fullPath)
    }
  }

  printDoctorSummary(createdFiles, targetDir)
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

  const fileWriter = new FileWriter()
  const defaultDir = resolve(process.cwd(), "shakapacker-config-exports")
  const targetDir = options.saveDir || defaultDir
  const configs = await loadConfigsForEnv(options.env, options, appRoot)

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
    fileWriter.writeSingleFile(resolve(options.output), output)
  } else {
    // Multi-file output (one per config)
    for (const { config, metadata } of configs) {
      const output = formatConfig(config, metadata, options, appRoot)
      const filename = fileWriter.generateFilename(
        metadata.bundler,
        metadata.environment,
        metadata.configType,
        options.format!,
        metadata.buildName
      )
      fileWriter.writeSingleFile(resolve(targetDir, filename), output)
    }
  }
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

async function loadConfigsForEnv(
  env: "development" | "production" | "test" | undefined,
  options: ExportOptions,
  appRoot: string
): Promise<Array<{ config: any; metadata: ConfigMetadata }>> {
  let bundler: "webpack" | "rspack"
  let buildName: string | undefined
  let buildOutputs: string[] = []
  let customConfigFile: string | undefined
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

    // Set environment variables from config
    // Security: Only allow specific environment variables to prevent malicious configs
    const ALLOWED_ENV_VARS = [
      "NODE_ENV",
      "RAILS_ENV",
      "NODE_OPTIONS",
      "BABEL_ENV",
      "WEBPACK_SERVE",
      "CLIENT_BUNDLE_ONLY",
      "SERVER_BUNDLE_ONLY"
    ]
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
      if (!ALLOWED_ENV_VARS.includes(key)) {
        console.warn(
          `[Config Exporter] Warning: Skipping non-whitelisted environment variable: ${key}. ` +
            `Allowed variables are: ${ALLOWED_ENV_VARS.join(", ")}`
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
  const configFile = customConfigFile || findConfigFile(bundler, appRoot)
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
        SERVER_BUNDLE_ONLY: process.env.SERVER_BUNDLE_ONLY
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
  } else if (options.format === "json") {
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
  try {
    const configPath =
      process.env.SHAKAPACKER_CONFIG ||
      resolve(appRoot, "config/shakapacker.yml")

    if (existsSync(configPath)) {
      const config: any = loadYaml(readFileSync(configPath, "utf8"))
      const envConfig = config[env] || config.default || {}
      const bundler = envConfig.assets_bundler || "webpack"
      if (bundler !== "webpack" && bundler !== "rspack") {
        console.warn(
          `[Config Exporter] Invalid bundler '${bundler}' in shakapacker.yml, defaulting to webpack`
        )
        return "webpack"
      }
      console.log(`[Config Exporter] Auto-detected bundler: ${bundler}`)
      return bundler
    }
  } catch (error: any) {
    console.warn(
      `[Config Exporter] Error detecting bundler, defaulting to webpack`
    )
  }

  return "webpack"
}

function findConfigFile(
  bundler: "webpack" | "rspack",
  appRoot: string
): string {
  const extensions = ["ts", "js"]

  if (bundler === "rspack") {
    for (const ext of extensions) {
      const rspackPath = resolve(appRoot, `config/rspack/rspack.config.${ext}`)
      if (existsSync(rspackPath)) {
        return rspackPath
      }
    }
  }

  // Fall back to webpack config
  for (const ext of extensions) {
    const webpackPath = resolve(appRoot, `config/webpack/webpack.config.${ext}`)
    if (existsSync(webpackPath)) {
      return webpackPath
    }
  }

  throw new Error(
    `Could not find ${bundler} config file. Expected: config/${bundler}/${bundler}.config.{js,ts}`
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
