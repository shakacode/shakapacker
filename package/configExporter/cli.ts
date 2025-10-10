// This will be a substantial file - the main CLI entry point
// Migrating from bin/export-bundler-config but streamlined for TypeScript

import { existsSync, readFileSync, writeFileSync } from "fs"
import { resolve, dirname, sep, delimiter, basename } from "path"
import { inspect } from "util"
import { load as loadYaml } from "js-yaml"
import { ExportOptions, ConfigMetadata, FileOutput } from "./types"
import { YamlSerializer } from "./yamlSerializer"
import { FileWriter } from "./fileWriter"
import { ConfigFileLoader, generateSampleConfigFile } from "./configFile"

// Main CLI entry point
export async function run(args: string[]): Promise<number> {
  try {
    const options = parseArguments(args)

    if (options.help) {
      showHelp()
      return 0
    }

    // Handle --init command
    if (options.init) {
      return runInitCommand(options)
    }

    // Handle --list-builds command
    if (options.listBuilds) {
      return runListBuildsCommand(options)
    }

    // Set up environment
    const appRoot = findAppRoot()
    process.chdir(appRoot)
    setupNodePath(appRoot)

    // Apply defaults
    applyDefaults(options)

    // Validate options
    validateOptions(options)

    // Execute based on mode
    if (options.doctor) {
      await runDoctorMode(options, appRoot)
    } else if (options.save) {
      await runSaveMode(options, appRoot)
    } else {
      await runStdoutMode(options, appRoot)
    }

    return 0
  } catch (error: any) {
    console.error(`[Config Exporter] Error: ${error.message}`)
    return 1
  }
}

function parseArguments(args: string[]): ExportOptions {
  const options: ExportOptions = {
    bundler: undefined,
    env: "development",
    clientOnly: false,
    serverOnly: false,
    output: undefined,
    depth: 20,
    format: undefined,
    help: false,
    verbose: false,
    doctor: false,
    save: false,
    saveDir: undefined,
    annotate: undefined,
    init: false,
    configFile: undefined,
    build: undefined,
    listBuilds: false
  }

  const parseValue = (arg: string, prefix: string): string => {
    const value = arg.substring(prefix.length)
    if (value.length === 0) {
      throw new Error(`${prefix} requires a value`)
    }
    return value
  }

  for (const arg of args) {
    if (arg === "--help" || arg === "-h") {
      options.help = true
    } else if (arg === "--doctor") {
      options.doctor = true
    } else if (arg === "--save") {
      options.save = true
    } else if (arg.startsWith("--save-dir=")) {
      options.saveDir = parseValue(arg, "--save-dir=")
    } else if (arg === "--webpack") {
      options.bundler = "webpack"
    } else if (arg === "--rspack") {
      options.bundler = "rspack"
    } else if (arg.startsWith("--bundler=")) {
      const bundler = parseValue(arg, "--bundler=")
      if (bundler !== "webpack" && bundler !== "rspack") {
        throw new Error(
          `Invalid bundler '${bundler}'. Must be 'webpack' or 'rspack'.`
        )
      }
      options.bundler = bundler
    } else if (arg.startsWith("--env=")) {
      const env = parseValue(arg, "--env=")
      if (env !== "development" && env !== "production" && env !== "test") {
        throw new Error(
          `Invalid environment '${env}'. Must be 'development', 'production', or 'test'.`
        )
      }
      options.env = env
    } else if (arg === "--client-only") {
      options.clientOnly = true
    } else if (arg === "--server-only") {
      options.serverOnly = true
    } else if (arg.startsWith("--output=")) {
      options.output = parseValue(arg, "--output=")
    } else if (arg.startsWith("--depth=")) {
      const depth = parseValue(arg, "--depth=")
      options.depth = depth === "null" ? null : parseInt(depth, 10)
    } else if (arg.startsWith("--format=")) {
      const format = parseValue(arg, "--format=")
      if (format !== "yaml" && format !== "json" && format !== "inspect") {
        throw new Error(
          `Invalid format '${format}'. Must be 'yaml', 'json', or 'inspect'.`
        )
      }
      options.format = format
    } else if (arg === "--no-annotate") {
      options.annotate = false
    } else if (arg === "--verbose") {
      options.verbose = true
    } else if (arg === "--init") {
      options.init = true
    } else if (arg.startsWith("--config-file=")) {
      options.configFile = parseValue(arg, "--config-file=")
    } else if (arg.startsWith("--build=")) {
      options.build = parseValue(arg, "--build=")
    } else if (arg === "--list-builds") {
      options.listBuilds = true
    }
  }

  return options
}

function applyDefaults(options: ExportOptions): void {
  if (options.doctor) {
    options.save = true
    if (options.format === undefined) options.format = "yaml"
    if (options.annotate === undefined) options.annotate = true
  } else if (options.save) {
    if (options.format === undefined) options.format = "yaml"
    if (options.annotate === undefined) options.annotate = true
  } else {
    if (options.format === undefined) options.format = "inspect"
    if (options.annotate === undefined) options.annotate = false
  }
}

function validateOptions(options: ExportOptions): void {
  if (options.clientOnly && options.serverOnly) {
    throw new Error(
      "--client-only and --server-only are mutually exclusive. Please specify only one."
    )
  }

  if (options.saveDir && !options.save && !options.doctor) {
    throw new Error("--save-dir requires --save or --doctor flag.")
  }

  if (options.output && options.saveDir) {
    throw new Error(
      "--output and --save-dir are mutually exclusive. Use one or the other."
    )
  }

  if (options.annotate && options.format !== "yaml") {
    throw new Error(
      "--annotate (or default with --save/--doctor) requires --format=yaml. Use --no-annotate or --format=inspect/json."
    )
  }

  if (options.build) {
    const loader = new ConfigFileLoader(options.configFile)
    if (!loader.exists()) {
      const configPath = options.configFile || ".bundler-config.yml"
      throw new Error(
        `--build requires a config file but ${configPath} not found. Run --init to create it.`
      )
    }
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

async function runDoctorMode(
  options: ExportOptions,
  appRoot: string
): Promise<void> {
  console.log("\n" + "=".repeat(80))
  console.log("🔍 Config Exporter - Doctor Mode")
  console.log("=".repeat(80))
  console.log("\nExporting development AND production configs...")
  console.log("")

  const environments: Array<"development" | "production"> = [
    "development",
    "production"
  ]
  const fileWriter = new FileWriter()
  const defaultDir = resolve(process.cwd(), "shakapacker-config-exports")
  const targetDir = options.saveDir || defaultDir

  const createdFiles: string[] = []

  for (const env of environments) {
    console.log(`\n📦 Loading ${env} configuration...`)
    const configs = await loadConfigsForEnv(env, options, appRoot)

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
      const fileOutput: FileOutput = { filename, content: output, metadata }
      fileWriter.writeSingleFile(fullPath, output, true) // quiet mode
      createdFiles.push(fullPath)
    }
  }

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
  console.log(`[Config Exporter] Save mode: Exporting ${options.env} configs`)

  const fileWriter = new FileWriter()
  const targetDir = options.saveDir || process.cwd()
  const configs = await loadConfigsForEnv(options.env!, options, appRoot)

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
  env: "development" | "production" | "test",
  options: ExportOptions,
  appRoot: string
): Promise<Array<{ config: any; metadata: ConfigMetadata }>> {
  let bundler: "webpack" | "rspack"
  let buildName: string | undefined
  let buildOutputs: string[] = []
  let customConfigFile: string | undefined

  // If using config file build
  if (options.build) {
    const loader = new ConfigFileLoader(options.configFile)
    const defaultBundler = await autoDetectBundler(env, appRoot)
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
    for (const [key, value] of Object.entries(resolvedBuild.environment)) {
      process.env[key] = value
    }

    // Use env from config if not overridden by CLI
    if (resolvedBuild.environment.NODE_ENV && !options.env) {
      env = resolvedBuild.environment.NODE_ENV as
        | "development"
        | "production"
        | "test"
    }
  } else {
    // Auto-detect bundler if not specified
    bundler = options.bundler || (await autoDetectBundler(env, appRoot))

    // Set environment variables
    process.env.NODE_ENV = env
    process.env.RAILS_ENV = env
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
    console.log(`[Config Exporter] Environment: ${env}`)
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
  // This is critical for loading different environments in the same process
  // MUST clear shakapacker env module cache so env.nodeEnv is re-read!
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
        console.warn(
          `[Config Exporter] Warning: Invalid output type '${outputValue}' at index ${index}, using 'all'`
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
      environment: env,
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

function showHelp(): void {
  console.log(`
Shakapacker Config Exporter

Exports webpack or rspack configuration in a verbose, human-readable format
for comparison and analysis.

QUICK START:
  # Initialize config file with build definitions
  bin/export-bundler-config --init

  # List available builds from config file
  bin/export-bundler-config --list-builds

  # Export a specific build
  bin/export-bundler-config --build=dev --save

  # Troubleshooting mode (exports dev + prod)
  bin/export-bundler-config --doctor

Usage:
  bin/export-bundler-config [options]

Config File Options:
  --init                     Generate sample .bundler-config.yml with examples
  --config-file=<path>       Path to config file (default: .bundler-config.yml)
  --build=<name>             Export config for specific build from config file
  --list-builds              List all available builds from config file

Bundler Selection:
  --webpack                  Use webpack (overrides config file)
  --rspack                   Use rspack (overrides config file)
  --bundler=webpack|rspack   Alternative syntax (auto-detected if not provided)

Export Modes:
  --doctor                   Export all configs for troubleshooting (dev + prod, annotated YAML)
  --save                     Save to auto-generated file(s) (default: YAML format)
  --save-dir=<directory>     Directory for output files (requires --save)
  --output=<filename>        Output to specific file (default: stdout)

Environment Options:
  --env=development|production|test    Node environment (default: development)
  --client-only              Generate only client config (sets CLIENT_BUNDLE_ONLY=yes)
  --server-only              Generate only server config (sets SERVER_BUNDLE_ONLY=yes)

Output Format:
  --format=yaml|json|inspect Output format (default: inspect for stdout, yaml for --save/--doctor)
  --no-annotate              Disable inline documentation (YAML only)
  --depth=<number>           Inspection depth (default: 20, use 'null' for unlimited)
  --verbose                  Show full output without compact mode
  --help, -h                 Show this help message

Examples:

  # Config File Workflow
  bin/export-bundler-config --init
  bin/export-bundler-config --list-builds
  bin/export-bundler-config --build=dev --save
  bin/export-bundler-config --build=dev --save --rspack

  # Traditional Workflow (without config file)
  bin/export-bundler-config --doctor
  bin/export-bundler-config --save --env=production --client-only
  bin/export-bundler-config --save --save-dir=./debug

Output File Naming:
  Without build: {bundler}-{env}-{type}.{ext}
    Example: webpack-development-client.yaml

  With build: {bundler}-{build}-{type}.{ext}
    Example: webpack-dev-client.yaml, rspack-cypress-dev-server.yaml
`)
}
