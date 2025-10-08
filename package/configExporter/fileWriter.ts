import { writeFileSync, mkdirSync, existsSync } from "fs"
import { resolve, dirname } from "path"
import { FileOutput } from "./types"

/**
 * Handles writing config exports to files.
 * Supports single file output or multiple files (one per config).
 */
export class FileWriter {
  /**
   * Write multiple config files (one per config in array)
   */
  writeMultipleFiles(outputs: FileOutput[], targetDir: string): void {
    // Ensure directory exists
    this.ensureDirectory(targetDir)

    // Write each file
    outputs.forEach((output) => {
      const filePath = resolve(targetDir, output.filename)
      this.writeFile(filePath, output.content)
      console.log(`[Config Exporter] Created: ${filePath}`)
    })

    console.log(
      `[Config Exporter] Exported ${outputs.length} config file(s) to ${targetDir}`
    )
  }

  /**
   * Write a single file
   */
  writeSingleFile(filePath: string, content: string): void {
    // Ensure parent directory exists
    const dir = dirname(filePath)
    this.ensureDirectory(dir)

    this.writeFile(filePath, content)
    console.log(`[Config Exporter] Config exported to: ${filePath}`)
  }

  /**
   * Generate filename for a config export
   * Format: {bundler}-{env}-{type}.{ext}
   * Examples:
   *   webpack-development-client.yaml
   *   rspack-production-server.yaml
   *   webpack-test-all.json
   */
  generateFilename(
    bundler: string,
    env: string,
    configType: "client" | "server" | "all",
    format: "yaml" | "json" | "inspect"
  ): string {
    const ext = format === "yaml" ? "yaml" : format === "json" ? "json" : "txt"
    return `${bundler}-${env}-${configType}.${ext}`
  }

  private writeFile(filePath: string, content: string): void {
    writeFileSync(filePath, content, "utf8")
  }

  private ensureDirectory(dir: string): void {
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true })
    }
  }

  /**
   * Validate output path and warn if writing outside cwd
   */
  validateOutputPath(outputPath: string): void {
    const absPath = resolve(outputPath)
    const cwd = process.cwd()

    if (!absPath.startsWith(cwd) && !absPath.startsWith("/tmp")) {
      console.warn(
        `[Config Exporter] Warning: Writing to ${absPath} which is outside current directory`
      )
    }
  }
}
