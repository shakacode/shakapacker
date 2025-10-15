import { writeFileSync, mkdirSync, existsSync } from "fs"
import { resolve, dirname, relative, isAbsolute, basename } from "path"
import { tmpdir } from "os"
import { FileOutput } from "./types"

/**
 * Handles writing config exports to files.
 * Supports single file output or multiple files (one per config).
 */
export class FileWriter {
  /**
   * Write multiple config files (one per config in array)
   */
  static writeMultipleFiles(outputs: FileOutput[], targetDir: string): void {
    // Ensure directory exists
    FileWriter.ensureDirectory(targetDir)

    // Write each file
    outputs.forEach((output) => {
      const safeName = basename(output.filename)
      const filePath = resolve(targetDir, safeName)
      FileWriter.validateOutputPath(filePath)
      FileWriter.writeFile(filePath, output.content)
      console.log(`[Config Exporter] Created: ${filePath}`)
    })

    console.log(
      `[Config Exporter] Exported ${outputs.length} config file(s) to ${targetDir}`
    )
  }

  /**
   * Write a single file
   */
  static writeSingleFile(filePath: string, content: string): void {
    // Ensure parent directory exists
    const dir = dirname(filePath)
    FileWriter.ensureDirectory(dir)

    FileWriter.validateOutputPath(filePath)
    FileWriter.writeFile(filePath, content)
    console.log(`[Config Exporter] Created: ${filePath}`)
  }

  /**
   * Generate filename for a config export
   * Format without build: {bundler}-{env}-{type}.{ext}
   * Format with build: {bundler}-{build}-{type}.{ext}
   * Examples:
   *   webpack-development-client.yaml
   *   rspack-production-server.yaml
   *   webpack-test-all.json
   *   webpack-development-client-hmr.yaml
   *   webpack-dev-client.yaml (with build name)
   *   rspack-cypress-dev-server.yaml (with build name)
   */
  static generateFilename(
    bundler: string,
    env: string,
    configType: "client" | "server" | "all" | "client-hmr",
    format: "yaml" | "json" | "inspect",
    buildName?: string
  ): string {
    const ext = format === "yaml" ? "yaml" : format === "json" ? "json" : "txt"
    const name = buildName || env
    return `${bundler}-${name}-${configType}.${ext}`
  }

  private static writeFile(filePath: string, content: string): void {
    writeFileSync(filePath, content, "utf8")
  }

  private static ensureDirectory(dir: string): void {
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true })
    }
  }

  /**
   * Validate output path and warn if writing outside cwd
   */
  static validateOutputPath(outputPath: string): void {
    const absPath = resolve(outputPath)
    const cwd = process.cwd()

    const isWithin = (base: string, target: string) => {
      const rel = relative(base, target)
      return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel))
    }
    if (!isWithin(cwd, absPath) && !isWithin(tmpdir(), absPath)) {
      console.warn(
        `[Config Exporter] Warning: Writing to ${absPath} which is outside current directory (${cwd}) or temp (${tmpdir()})`
      )
    }
  }
}
