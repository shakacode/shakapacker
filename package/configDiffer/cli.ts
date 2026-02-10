import { existsSync, readFileSync } from "fs"
import { resolve, extname } from "path"
import { load as loadYaml } from "js-yaml"
import { DiffEngine } from "./diffEngine"
import { DiffFormatter } from "./formatter"
import { PathNormalizer } from "./pathNormalizer"
import { DiffOptions } from "./types"

interface CliOptions extends DiffOptions {
  leftFile: string
  rightFile: string
  output?: string
  help?: boolean
}

export function run(args: string[]): number {
  try {
    const options = parseArguments(args)

    if (options.help) {
      showHelp()
      return 0
    }

    if (!options.leftFile || !options.rightFile) {
      console.error(
        "Error: Both --left and --right files are required. Use --help for usage information."
      )
      return 1
    }

    const leftConfig = loadConfigFile(options.leftFile)
    const rightConfig = loadConfigFile(options.rightFile)

    let normalizedLeft = leftConfig
    let normalizedRight = rightConfig

    if (options.normalizePaths) {
      const leftBasePath =
        PathNormalizer.detectBasePath(leftConfig) || process.cwd()
      const rightBasePath =
        PathNormalizer.detectBasePath(rightConfig) || process.cwd()

      const leftNormalizer = new PathNormalizer(leftBasePath)
      const rightNormalizer = new PathNormalizer(rightBasePath)

      normalizedLeft = leftNormalizer.normalize(leftConfig).normalized
      normalizedRight = rightNormalizer.normalize(rightConfig).normalized
    }

    const diffEngine = new DiffEngine(options)
    const result = diffEngine.compare(normalizedLeft, normalizedRight, {
      leftFile: options.leftFile,
      rightFile: options.rightFile
    })

    const formatter = new DiffFormatter()
    let output: string

    switch (options.format) {
      case "json":
        output = formatter.formatJson(result)
        break
      case "yaml":
        output = formatter.formatYaml(result)
        break
      case "summary":
        output = formatter.formatSummary(result)
        break
      case "detailed":
      default:
        output = formatter.formatDetailed(result)
        break
    }

    if (options.output) {
      const fs = require("fs")
      fs.writeFileSync(options.output, output, "utf8")
      console.log(`Diff written to: ${options.output}`)
    } else {
      console.log(output)
    }

    return result.summary.totalChanges > 0 ? 1 : 0
  } catch (error: any) {
    console.error(`Error: ${error.message}`)
    return 1
  }
}

function parseArguments(args: string[]): CliOptions {
  const options: CliOptions = {
    leftFile: "",
    rightFile: "",
    output: undefined,
    format: "detailed",
    includeUnchanged: false,
    maxDepth: null,
    ignoreKeys: [],
    ignorePaths: [],
    normalizePaths: true,
    pathSeparator: ".",
    help: false
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
    } else if (arg.startsWith("--left=")) {
      options.leftFile = parseValue(arg, "--left=")
    } else if (arg.startsWith("--right=")) {
      options.rightFile = parseValue(arg, "--right=")
    } else if (arg.startsWith("--output=")) {
      options.output = parseValue(arg, "--output=")
    } else if (arg.startsWith("--format=")) {
      const format = parseValue(arg, "--format=")
      if (
        format !== "json" &&
        format !== "yaml" &&
        format !== "summary" &&
        format !== "detailed"
      ) {
        throw new Error(
          `Invalid format '${format}'. Must be 'json', 'yaml', 'summary', or 'detailed'.`
        )
      }
      options.format = format
    } else if (arg === "--include-unchanged") {
      options.includeUnchanged = true
    } else if (arg.startsWith("--max-depth=")) {
      const depth = parseValue(arg, "--max-depth=")
      options.maxDepth = depth === "null" ? null : parseInt(depth, 10)
    } else if (arg.startsWith("--ignore-keys=")) {
      const keys = parseValue(arg, "--ignore-keys=")
      options.ignoreKeys = keys.split(",").map((k) => k.trim())
    } else if (arg.startsWith("--ignore-paths=")) {
      const paths = parseValue(arg, "--ignore-paths=")
      options.ignorePaths = paths.split(",").map((p) => p.trim())
    } else if (arg === "--no-normalize-paths") {
      options.normalizePaths = false
    } else if (arg.startsWith("--path-separator=")) {
      options.pathSeparator = parseValue(arg, "--path-separator=")
    }
  }

  return options
}

function loadConfigFile(filePath: string): any {
  const resolvedPath = resolve(process.cwd(), filePath)

  if (!existsSync(resolvedPath)) {
    throw new Error(`File not found: ${resolvedPath}`)
  }

  const ext = extname(resolvedPath).toLowerCase()
  const content = readFileSync(resolvedPath, "utf8")

  if (ext === ".json") {
    return JSON.parse(content)
  }
  if (ext === ".yaml" || ext === ".yml") {
    return loadYaml(content)
  }
  if (ext === ".js" || ext === ".ts") {
    if (ext === ".ts") {
      try {
        require("ts-node/register/transpile-only")
      } catch {
        throw new Error(
          "TypeScript config detected but ts-node is not available. " +
            "Install ts-node as a dev dependency: npm install --save-dev ts-node"
        )
      }
    }

    delete require.cache[resolvedPath]
    let loaded = require(resolvedPath)

    if (typeof loaded === "object" && "default" in loaded) {
      loaded = loaded.default
    }

    return loaded
  }
  throw new Error(
    `Unsupported file format: ${ext}. Supported formats: .json, .yaml, .yml, .js, .ts`
  )
}

function showHelp(): void {
  console.log(`
Shakapacker Config Differ

Compare two webpack/rspack configuration files and identify differences.

Usage:
  bin/diff-bundler-config --left=<file1> --right=<file2> [options]

Required Options:
  --left=<file>              Path to the first (left) config file
  --right=<file>             Path to the second (right) config file

Output Options:
  --format=<format>          Output format: detailed, summary, json, yaml (default: detailed)
  --output=<file>            Write output to file instead of stdout

Comparison Options:
  --include-unchanged        Include unchanged values in output
  --max-depth=<number>       Maximum depth for comparison (default: unlimited)
  --ignore-keys=<keys>       Comma-separated list of keys to ignore
  --ignore-paths=<paths>     Comma-separated list of paths to ignore (supports wildcards)
  --no-normalize-paths       Disable automatic path normalization
  --path-separator=<sep>     Path separator for human-readable paths (default: ".")

Other Options:
  --help, -h                 Show this help message

Supported File Formats:
  - JSON (.json)
  - YAML (.yaml, .yml)
  - JavaScript (.js)
  - TypeScript (.ts) - requires ts-node

Examples:
  # Compare two exported YAML configs
  bin/diff-bundler-config \\
    --left=webpack-development-client.yaml \\
    --right=webpack-production-client.yaml

  # Compare with summary output
  bin/diff-bundler-config \\
    --left=config1.yaml \\
    --right=config2.yaml \\
    --format=summary

  # Compare and save to file
  bin/diff-bundler-config \\
    --left=config1.json \\
    --right=config2.json \\
    --output=diff-report.txt

  # Compare with specific paths ignored
  bin/diff-bundler-config \\
    --left=config1.yaml \\
    --right=config2.yaml \\
    --ignore-paths="plugins.*,output.path"

Exit Codes:
  0 - Success, no differences found
  1 - Differences found or error occurred
`)
}
