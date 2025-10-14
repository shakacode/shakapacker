import { spawn } from "child_process"
import { existsSync } from "fs"
import { resolve } from "path"
import { ResolvedBuildConfig, BuildValidationResult } from "./types"

export interface ValidatorOptions {
  verbose: boolean
  timeout?: number // milliseconds
}

/**
 * TypeScript interface for webpack/rspack JSON output structure
 */
interface WebpackJsonOutput {
  errors?: Array<string | { message: string }>
  warnings?: Array<string | { message: string }>
  hash?: string
  time?: number
  builtAt?: number
}

/**
 * Whitelisted environment variables that are safe to pass to build processes.
 * This prevents arbitrary environment variable injection from config files.
 *
 * Note: PATH is essential for webpack/rspack to find node and other binaries.
 * HOME is needed for tools that read user config (e.g., .npmrc, .yarnrc).
 */
const SAFE_ENV_VARS = [
  "PATH",
  "HOME",
  "NODE_ENV",
  "RAILS_ENV",
  "NODE_OPTIONS",
  "BABEL_ENV",
  "WEBPACK_SERVE",
  "CLIENT_BUNDLE_ONLY",
  "SERVER_BUNDLE_ONLY",
  "PUBLIC_URL",
  "ASSET_HOST",
  "CDN_HOST",
  "TMPDIR",
  "TEMP",
  "TMP"
] as const

/**
 * Success patterns for detecting successful compilation in webpack/rspack output
 */
const SUCCESS_PATTERNS = [
  "webpack compiled",
  "Compiled successfully",
  "rspack compiled successfully",
  "webpack: Compiled successfully",
  "Compilation completed",
  "Built at:",
  "wds: Compiled successfully" // webpack-dev-server specific
]

/**
 * Error patterns for detecting compilation errors in webpack/rspack output
 */
const ERROR_PATTERNS = ["ERROR", "Error:", "Failed to compile"]

/**
 * Warning patterns for detecting compilation warnings in webpack/rspack output
 */
const WARNING_PATTERNS = ["WARNING", "Warning:"]

/**
 * Important error details to capture even in non-verbose mode
 */
const IMPORTANT_ERROR_PATTERNS = [
  "Module not found",
  "Can't resolve",
  "SyntaxError"
]

/**
 * Validates webpack/rspack builds by running them and checking for errors
 * For HMR builds, starts webpack-dev-server and shuts down after successful start
 */
export class BuildValidator {
  private options: ValidatorOptions

  constructor(options: ValidatorOptions) {
    this.options = {
      verbose: options.verbose,
      timeout: options.timeout || 120000 // 2 minutes default
    }
  }

  /**
   * Filters environment variables to only include whitelisted safe variables.
   * This prevents command injection and limits exposure of sensitive data.
   */
  private filterEnvironment(
    buildEnv: Record<string, string>
  ): Record<string, string> {
    const filtered: Record<string, string> = {}

    // Start with current process.env but only whitelisted vars
    SAFE_ENV_VARS.forEach((key) => {
      if (process.env[key]) {
        filtered[key] = process.env[key]!
      }
    })

    // Override with build-specific env vars (also filtered)
    Object.entries(buildEnv).forEach(([key, value]) => {
      if ((SAFE_ENV_VARS as readonly string[]).includes(key)) {
        filtered[key] = value
      }
    })

    return filtered
  }

  /**
   * Validates a single build configuration
   */
  async validateBuild(
    build: ResolvedBuildConfig,
    appRoot: string
  ): Promise<BuildValidationResult> {
    const isHMR = build.environment.WEBPACK_SERVE === "true"
    const bundler = build.bundler

    if (isHMR) {
      return this.validateHMRBuild(build, appRoot, bundler)
    } else {
      return this.validateStaticBuild(build, appRoot, bundler)
    }
  }

  /**
   * Validates an HMR build by starting webpack-dev-server
   * Waits for successful compilation, then shuts down
   */
  private async validateHMRBuild(
    build: ResolvedBuildConfig,
    appRoot: string,
    bundler: "webpack" | "rspack"
  ): Promise<BuildValidationResult> {
    const result: BuildValidationResult = {
      buildName: build.name,
      success: false,
      errors: [],
      warnings: [],
      output: []
    }

    // Determine the dev server command
    const devServerCmd =
      bundler === "rspack" ? "rspack-dev-server" : "webpack-dev-server"
    const devServerBin = this.findBinary(devServerCmd, appRoot)

    if (!devServerBin) {
      result.errors.push(
        `Could not find ${devServerCmd} binary. Please install ${bundler}-dev-server.`
      )
      return result
    }

    // Build arguments
    const args: string[] = []

    // Add config file if specified
    if (build.configFile) {
      const configPath = resolve(appRoot, build.configFile)
      if (!existsSync(configPath)) {
        result.errors.push(
          `Config file not found: ${configPath}. Check the 'config' setting in your build configuration.`
        )
        return result
      }
      args.push("--config", configPath)
    } else {
      // Use default config path
      const defaultConfig = resolve(
        appRoot,
        `config/${bundler}/${bundler}.config.js`
      )
      if (existsSync(defaultConfig)) {
        args.push("--config", defaultConfig)
      }
    }

    // Add bundler env args (--env flags)
    if (build.bundlerEnvArgs && build.bundlerEnvArgs.length > 0) {
      args.push(...build.bundlerEnvArgs)
    }

    return new Promise((resolve) => {
      const child = spawn(devServerBin, args, {
        cwd: appRoot,
        env: this.filterEnvironment(build.environment),
        stdio: ["ignore", "pipe", "pipe"]
      })

      let hasCompiled = false
      let hasError = false
      let resolved = false

      const resolveOnce = (res: BuildValidationResult) => {
        if (!resolved) {
          resolved = true
          resolve(res)
        }
      }

      const timeoutId = setTimeout(() => {
        if (!hasCompiled && !hasError && !resolved) {
          result.errors.push(
            `Timeout: webpack-dev-server did not compile within ${this.options.timeout}ms.`
          )
          child.kill("SIGTERM")
          // Remove listeners to prevent further callbacks
          child.stdout?.removeAllListeners()
          child.stderr?.removeAllListeners()
          child.removeAllListeners()
          resolveOnce(result)
        }
      }, this.options.timeout)

      const processOutput = (data: Buffer) => {
        const lines = data.toString().split("\n")
        lines.forEach((line) => {
          if (!line.trim()) return

          // Always output in real-time in verbose mode so user sees progress
          if (this.options.verbose) {
            console.log(`   ${line}`)
          }

          // Store all output
          result.output.push(line)

          // Check for successful compilation
          if (SUCCESS_PATTERNS.some((pattern) => line.includes(pattern))) {
            hasCompiled = true
            result.success = true
            clearTimeout(timeoutId)
            child.kill("SIGTERM")
            // Small delay to allow process to clean up before removing listeners
            setTimeout(() => {
              child.stdout?.removeAllListeners()
              child.stderr?.removeAllListeners()
              child.removeAllListeners()
            }, 100)
            resolveOnce(result)
          }

          // Check for errors
          if (ERROR_PATTERNS.some((pattern) => line.includes(pattern))) {
            hasError = true
            result.errors.push(line)
          }

          // Check for warnings
          if (WARNING_PATTERNS.some((pattern) => line.includes(pattern))) {
            result.warnings.push(line)
          }
        })
      }

      child.stdout?.on("data", (data) => processOutput(data))
      child.stderr?.on("data", (data) => processOutput(data))

      child.on("exit", (code) => {
        clearTimeout(timeoutId)
        if (!hasCompiled && !hasError && !resolved) {
          const SIGTERM_EXIT_CODE = 143
          if (code !== 0 && code !== null && code !== SIGTERM_EXIT_CODE) {
            result.errors.push(
              `webpack-dev-server exited with code ${code} before compilation completed.`
            )
          }
        }
        resolveOnce(result)
      })

      child.on("error", (err) => {
        clearTimeout(timeoutId)
        result.errors.push(
          `Failed to start webpack-dev-server: ${err.message}.`
        )
        resolveOnce(result)
      })
    })
  }

  /**
   * Validates a static build by running webpack/rspack in production mode
   * Uses --json flag to get structured output
   */
  private async validateStaticBuild(
    build: ResolvedBuildConfig,
    appRoot: string,
    bundler: "webpack" | "rspack"
  ): Promise<BuildValidationResult> {
    const result: BuildValidationResult = {
      buildName: build.name,
      success: false,
      errors: [],
      warnings: [],
      output: []
    }

    const bundlerBin = this.findBinary(bundler, appRoot)

    if (!bundlerBin) {
      result.errors.push(
        `Could not find ${bundler} binary. Please install ${bundler}.`
      )
      return result
    }

    // Build arguments - use --dry-run if available, otherwise just build
    const args: string[] = []

    // Add config file if specified
    if (build.configFile) {
      const configPath = resolve(appRoot, build.configFile)
      if (!existsSync(configPath)) {
        result.errors.push(
          `Config file not found: ${configPath}. Check the 'config' setting in your build configuration.`
        )
        return result
      }
      args.push("--config", configPath)
    } else {
      // Use default config path
      const defaultConfig = resolve(
        appRoot,
        `config/${bundler}/${bundler}.config.js`
      )
      if (existsSync(defaultConfig)) {
        args.push("--config", defaultConfig)
      }
    }

    // Add bundler env args (--env flags)
    if (build.bundlerEnvArgs && build.bundlerEnvArgs.length > 0) {
      args.push(...build.bundlerEnvArgs)
    }

    // Add --json for structured output (helps parse errors)
    args.push("--json")

    return new Promise((resolve) => {
      const child = spawn(bundlerBin, args, {
        cwd: appRoot,
        env: this.filterEnvironment(build.environment),
        stdio: ["ignore", "pipe", "pipe"]
      })

      const stdoutChunks: Buffer[] = []
      const stderrChunks: Buffer[] = []
      const MAX_BUFFER_SIZE = 10 * 1024 * 1024 // 10MB limit to prevent memory issues

      let stdoutSize = 0
      let stderrSize = 0
      let bufferOverflow = false

      const timeoutId = setTimeout(() => {
        result.errors.push(
          `Timeout: ${bundler} did not complete within ${this.options.timeout}ms.`
        )
        child.kill("SIGTERM")
        resolve(result)
      }, this.options.timeout)

      child.stdout?.on("data", (data: Buffer) => {
        // Check buffer size to prevent memory issues
        if (stdoutSize + data.length > MAX_BUFFER_SIZE) {
          if (!bufferOverflow) {
            bufferOverflow = true
            result.warnings.push(
              `Output buffer limit exceeded (${MAX_BUFFER_SIZE} bytes). Some output may be truncated.`
            )
          }
        } else {
          stdoutChunks.push(data)
          stdoutSize += data.length
        }

        // Don't output JSON in verbose mode - it's too large and not useful
        // JSON is for parsing errors, not for human consumption
      })

      child.stderr?.on("data", (data: Buffer) => {
        // Check buffer size
        if (stderrSize + data.length > MAX_BUFFER_SIZE) {
          if (!bufferOverflow) {
            bufferOverflow = true
            result.warnings.push(
              `Output buffer limit exceeded (${MAX_BUFFER_SIZE} bytes). Some output may be truncated.`
            )
          }
        } else {
          stderrChunks.push(data)
          stderrSize += data.length
        }

        // In verbose mode, show useful stderr output (warnings, progress, etc.)
        if (this.options.verbose) {
          const output = data.toString()
          // Only show meaningful output, not just noise
          const lines = output.split("\n")
          lines.forEach((line) => {
            if (line.trim()) {
              console.log(`   ${line}`)
            }
          })
        }
      })

      child.on("exit", (code) => {
        clearTimeout(timeoutId)

        // Combine chunks into strings
        const stdoutData = Buffer.concat(stdoutChunks).toString()
        const stderrData = Buffer.concat(stderrChunks).toString()

        // Parse JSON output
        try {
          const jsonOutput: WebpackJsonOutput = JSON.parse(stdoutData)

          // Check for errors in webpack/rspack JSON output
          if (jsonOutput.errors && jsonOutput.errors.length > 0) {
            jsonOutput.errors.forEach((error) => {
              const errorMsg =
                typeof error === "string"
                  ? error
                  : error.message || String(error)
              result.errors.push(errorMsg)
              // Also add to output for visibility
              if (!this.options.verbose) {
                result.output.push(errorMsg)
              }
            })
          }

          // Check for warnings
          if (jsonOutput.warnings && jsonOutput.warnings.length > 0) {
            jsonOutput.warnings.forEach((warning) => {
              const warningMsg =
                typeof warning === "string"
                  ? warning
                  : warning.message || String(warning)
              result.warnings.push(warningMsg)
            })
          }

          result.success =
            code === 0 && (!jsonOutput.errors || jsonOutput.errors.length === 0)

          // If build failed but no errors were captured, add helpful message
          if (code !== 0 && result.errors.length === 0) {
            result.errors.push(
              `${bundler} exited with code ${code} but no errors were captured. ` +
                `This may indicate a configuration issue. Run with --verbose for full output.`
            )
          }
        } catch (err) {
          // If JSON parsing fails, fall back to stderr analysis
          if (stderrData && stderrData.length > 0) {
            const lines = stderrData.split("\n")
            lines.forEach((line) => {
              if (ERROR_PATTERNS.some((pattern) => line.includes(pattern))) {
                result.errors.push(line)
              }
              if (WARNING_PATTERNS.some((pattern) => line.includes(pattern))) {
                result.warnings.push(line)
              }
            })
          }

          if (code !== 0) {
            result.errors.push(`${bundler} exited with code ${code}.`)
          }

          result.success = code === 0 && result.errors.length === 0
        }

        // Add stderr to output if there were errors and not verbose
        if (
          !this.options.verbose &&
          result.errors.length > 0 &&
          stderrData &&
          stderrData.length > 0
        ) {
          result.output.push(stderrData)
        }

        resolve(result)
      })

      child.on("error", (err) => {
        clearTimeout(timeoutId)
        result.errors.push(`Failed to start ${bundler}: ${err.message}.`)
        resolve(result)
      })
    })
  }

  /**
   * Finds the binary for webpack, rspack, or dev servers
   */
  private findBinary(name: string, appRoot: string): string | null {
    // Try node_modules/.bin
    const nodeModulesBin = resolve(appRoot, "node_modules", ".bin", name)
    if (existsSync(nodeModulesBin)) {
      return nodeModulesBin
    }

    // Try global
    const globalBin = resolve("/usr/local/bin", name)
    if (existsSync(globalBin)) {
      return globalBin
    }

    // Try npx (will use PATH)
    return name
  }

  /**
   * Formats validation results for display
   */
  formatResults(results: BuildValidationResult[]): string {
    const lines: string[] = []

    lines.push("\n" + "=".repeat(80))
    lines.push("🔍 Build Validation Results")
    lines.push("=".repeat(80) + "\n")

    let totalBuilds = results.length
    let successCount = 0
    let failureCount = 0

    results.forEach((result) => {
      if (result.success) {
        successCount++
      } else {
        failureCount++
      }

      const icon = result.success ? "✅" : "❌"
      lines.push(`${icon} Build: ${result.buildName}`)

      if (result.warnings.length > 0) {
        lines.push(`   ⚠️  ${result.warnings.length} warning(s)`)
      }

      if (result.errors.length > 0) {
        lines.push(`   ❌ ${result.errors.length} error(s)`)
        result.errors.forEach((error) => {
          lines.push(`      ${error}`)
        })
      }

      // Always show output if there are errors (unless verbose already showing it)
      if (
        result.output.length > 0 &&
        (this.options.verbose || result.errors.length > 0)
      ) {
        lines.push("\n   Full Output:")
        result.output.forEach((line) => {
          lines.push(`   ${line}`)
        })
      }

      lines.push("")
    })

    lines.push("=".repeat(80))
    lines.push(
      `Summary: ${successCount}/${totalBuilds} builds passed, ${failureCount} failed`
    )
    lines.push("=".repeat(80) + "\n")

    return lines.join("\n")
  }
}
