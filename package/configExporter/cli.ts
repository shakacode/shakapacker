// This will be a substantial file - the main CLI entry point
// Migrating from bin/export-bundler-config but streamlined for TypeScript

import { existsSync, readFileSync } from "fs"
import { resolve, dirname, sep, delimiter, basename } from "path"
import { inspect } from "util"
import { load as loadYaml } from "js-yaml"
import { ExportOptions, ConfigMetadata, FileOutput } from "./types"
import { YamlSerializer } from "./yamlSerializer"
import { FileWriter } from "./fileWriter"

// Main CLI entry point
export async function run(args: string[]): Promise<number> {
  try {
    const options = parseArguments(args)

    if (options.help) {
      showHelp()
      return 0
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
    annotate: undefined
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
        options.format!
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
        options.format!
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
  // Auto-detect bundler if not specified
  const bundler = options.bundler || (await autoDetectBundler(env, appRoot))

  // Set environment variables
  process.env.NODE_ENV = env
  process.env.RAILS_ENV = env

  if (options.clientOnly) {
    process.env.CLIENT_BUNDLE_ONLY = "yes"
  } else if (options.serverOnly) {
    process.env.SERVER_BUNDLE_ONLY = "yes"
  }

  // Find and load config file
  const configFile = findConfigFile(bundler, appRoot)
  // Quiet mode for cleaner output - only show if verbose or errors
  if (process.env.VERBOSE) {
    console.log(`[Config Exporter] Loading config: ${configFile}`)
    console.log(`[Config Exporter] Environment: ${env}`)
    console.log(`[Config Exporter] Bundler: ${bundler}`)
  }

  // Load the config
  // Register ts-node for TypeScript config files
  if (configFile.endsWith(".ts")) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    require("ts-node/register/transpile-only")
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

    // Try to infer config type from the config itself
    if (configs.length === 2) {
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

QUICK START (for troubleshooting):
  bin/export-bundler-config --doctor

  Exports annotated YAML configs for both development and production.
  Creates separate files for client and server bundles.
  Best for debugging, AI analysis, and comparing configurations.

Usage:
  bin/export-bundler-config [options]

Options:
  --doctor                   Export all configs for troubleshooting (dev + prod, annotated YAML)
  --save                     Save to auto-generated file(s) (default: YAML format)
  --save-dir=<directory>     Directory for output files (requires --save)
  --bundler=webpack|rspack   Specify bundler (auto-detected if not provided)
  --env=development|production|test    Node environment (default: development, ignored with --doctor)
  --client-only              Generate only client config (sets CLIENT_BUNDLE_ONLY=yes)
  --server-only              Generate only server config (sets SERVER_BUNDLE_ONLY=yes)
  --output=<filename>        Output to specific file (default: stdout)
  --depth=<number>           Inspection depth (default: 20, use 'null' for unlimited)
  --format=yaml|json|inspect Output format (default: inspect for stdout, yaml for --save/--doctor)
  --no-annotate              Disable inline documentation (YAML only)
  --verbose                  Show full output without compact mode
  --help, -h                 Show this help message

Note: --client-only and --server-only are mutually exclusive.
      --save-dir requires --save.
      --output and --save-dir are mutually exclusive.
      If neither --client-only nor --server-only specified, both configs are generated.

Examples:
  # RECOMMENDED: Export everything for troubleshooting
  bin/export-bundler-config --doctor
  # Creates: webpack-development-client.yaml, webpack-development-server.yaml,
  #          webpack-production-client.yaml, webpack-production-server.yaml

  # Save current environment configs
  bin/export-bundler-config --save
  # Creates: webpack-development-client.yaml, webpack-development-server.yaml

  # Save to specific directory
  bin/export-bundler-config --save --save-dir=./debug

  # Export only client config for production
  bin/export-bundler-config --save --env=production --client-only
  # Creates: webpack-production-client.yaml

  # View config in terminal (stdout)
  bin/export-bundler-config
`)
}
