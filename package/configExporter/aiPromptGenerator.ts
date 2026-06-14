import { basename } from "path"

/**
 * Generates the content and filename for an AI prompt that accompanies
 * webpack/rspack configuration exports. The prompt helps AI identify issues and
 * suggest optimizations for the bundler configuration. (Writing the file to
 * disk is the caller's responsibility.)
 */
export class AiPromptGenerator {
  /**
   * Generate a comprehensive AI analysis prompt based on exported config files.
   *
   * Every entry in `exportedFiles` is listed in the prompt. Filenames containing
   * recognizable markers (dev/development, prod/production, client, server, hmr)
   * get descriptive labels; anything else is listed without a description.
   *
   * @param exportedFiles - Array of exported config file basenames
   * @param targetDir - Directory where configs were exported (only its base name appears in the prompt)
   * @param bundler - The bundler label (e.g. "webpack", "rspack", or "webpack and rspack" for mixed-bundler exports)
   * @param includeReactOnRailsContext - Whether to include React on Rails specific context (defaults to true)
   * @returns Markdown-formatted AI prompt
   */
  static generatePrompt(
    exportedFiles: string[],
    targetDir: string,
    bundler: string,
    includeReactOnRailsContext = true
  ): string {
    const timestamp = new Date().toISOString()
    const sections: string[] = []

    // Header
    sections.push("# AI Configuration Analysis Request")
    sections.push("")
    sections.push(
      `This directory contains exported ${bundler} configuration files for analysis.`
    )
    sections.push(
      "Please analyze these configurations and provide recommendations."
    )
    sections.push("")

    // Context section
    sections.push("## Context")
    sections.push("")
    sections.push(`- **Bundler**: ${bundler}`)
    sections.push(`- **Exported At**: ${timestamp}`)
    // Only the directory name is included: users are encouraged to paste this
    // prompt into external AI assistants, so the absolute path (which can leak
    // a username or internal layout) is deliberately omitted.
    sections.push(`- **Export Directory**: ${basename(targetDir)}`)
    sections.push("")

    // Configuration files
    sections.push("## Configuration Files")
    sections.push("")
    if (exportedFiles.length > 0) {
      sections.push(
        "The following configuration files are available for analysis:"
      )
      sections.push("")
      for (const file of exportedFiles) {
        sections.push(AiPromptGenerator.describeExportedFile(file))
      }
      if (exportedFiles.some((f) => f.toLowerCase().includes("hmr"))) {
        sections.push("")
        sections.push(
          "The HMR config is especially useful for troubleshooting dev server, hot reload,"
        )
        sections.push("and live reload issues.")
      }
    } else {
      sections.push("No configuration files were exported.")
    }
    sections.push("")

    // React on Rails context
    if (includeReactOnRailsContext) {
      sections.push("## React on Rails Standard Configuration")
      sections.push("")
      sections.push(
        "If this project uses React on Rails, it typically includes these standard configuration files:"
      )
      sections.push("")
      sections.push(
        "1. **`config/webpack/webpack.config.js`** (or rspack equivalent)"
      )
      sections.push(
        "   - Main entry point that loads environment-specific configs"
      )
      sections.push("")
      sections.push("2. **`config/webpack/commonWebpackConfig.js`**")
      sections.push(
        "   - Shared configuration between client and server bundles"
      )
      sections.push("   - Sets up common loaders, resolve extensions, etc.")
      sections.push("")
      sections.push("3. **`config/webpack/clientWebpackConfig.js`**")
      sections.push("   - Client-specific configuration")
      sections.push("   - Removes server-bundle entry")
      sections.push("   - Optimized for browser execution")
      sections.push("")
      sections.push("4. **`config/webpack/serverWebpackConfig.js`**")
      sections.push("   - Server-side rendering (SSR) configuration")
      sections.push("   - Single chunk output (no code splitting)")
      sections.push("   - Removes MiniCssExtractPlugin (CSS handled by client)")
      sections.push("   - Uses `css-loader` with `exportOnlyLocals: true`")
      sections.push("   - Target can be 'web' or 'node' depending on renderer")
      sections.push("")
      sections.push("### Reference Configuration Examples")
      sections.push("")
      sections.push(
        "For comparison, you can reference the standard React on Rails configuration examples:"
      )
      sections.push("")
      sections.push("**Source Configuration Files (JavaScript):**")
      sections.push("")
      sections.push(
        "- [commonWebpackConfig.js](https://github.com/shakacode/react_on_rails/blob/main/react_on_rails/spec/dummy/config/webpack/commonWebpackConfig.js)"
      )
      sections.push(
        "- [clientWebpackConfig.js](https://github.com/shakacode/react_on_rails/blob/main/react_on_rails/spec/dummy/config/webpack/clientWebpackConfig.js)"
      )
      sections.push(
        "- [serverWebpackConfig.js](https://github.com/shakacode/react_on_rails/blob/main/react_on_rails/spec/dummy/config/webpack/serverWebpackConfig.js)"
      )
      sections.push(
        "- [webpack.config.js](https://github.com/shakacode/react_on_rails/blob/main/react_on_rails/spec/dummy/config/webpack/webpack.config.js)"
      )
      sections.push("")
      sections.push(
        "These files demonstrate best practices for React on Rails webpack/rspack configuration."
      )
      sections.push("")
    }

    // Analysis requests
    sections.push("## Analysis Objectives")
    sections.push("")
    sections.push(
      "Please analyze the exported configuration files and provide:"
    )
    sections.push("")

    sections.push("### 1. Migration Issues")
    sections.push("")
    sections.push(
      "If this is a migration from webpack to rspack (or vice versa):"
    )
    sections.push("")
    sections.push("- Identify any incompatible plugins or loaders")
    sections.push("- Flag deprecated or removed options")
    sections.push("- Suggest equivalent replacements")
    sections.push(
      "- Check for rspack-specific optimizations that can be enabled"
    )
    sections.push("")

    sections.push("### 2. Build Errors & Warnings")
    sections.push("")
    sections.push(
      "Examine the configuration for common issues that cause build failures:"
    )
    sections.push("")
    sections.push("- Misconfigured loaders or plugins")
    sections.push("- Incorrect module resolution settings")
    sections.push("- Missing or incorrect output path configurations")
    sections.push("- Entry point issues")
    sections.push("- DevServer configuration problems")
    sections.push("")
    sections.push(
      "**Note**: If build error logs are provided separately (from `bin/shakapacker` or "
    )
    sections.push(
      "`bin/shakapacker-dev-server`), correlate them with configuration issues."
    )
    sections.push("")

    sections.push("### 3. Client vs Server Optimization")
    sections.push("")
    sections.push("Compare client and server configurations and recommend:")
    sections.push("")
    sections.push("**Client Bundle Optimizations:**")
    sections.push("- Code splitting strategy")
    sections.push("- Asset optimization (images, fonts)")
    sections.push("- CSS extraction and optimization")
    sections.push("- Tree shaking effectiveness")
    sections.push("- Bundle size reduction opportunities")
    sections.push("")
    sections.push("**Server Bundle Optimizations:**")
    sections.push("- Verify single-chunk output (no code splitting)")
    sections.push("- Ensure CSS is not extracted (handled by client)")
    sections.push("- Check for proper `exportOnlyLocals` for CSS modules")
    sections.push("- Validate target environment (web vs node)")
    sections.push("- Confirm assets are not emitted during SSR")
    sections.push("")

    sections.push("### 4. Development vs Production Optimization")
    sections.push("")
    sections.push("Compare development and production configurations:")
    sections.push("")
    sections.push("**Development:**")
    sections.push("- Fast rebuild times (appropriate devtool setting)")
    sections.push("- Hot Module Replacement (HMR) configuration")
    sections.push("- Detailed error messages")
    sections.push("- DevServer setup")
    sections.push("")
    sections.push("**Production:**")
    sections.push("- Minification and optimization")
    sections.push("- Source map strategy (balance between debugging and size)")
    sections.push("- Cache busting with content hashes")
    sections.push("- Compression and asset optimization")
    sections.push("- Performance budgets")
    sections.push("")

    sections.push("### 5. Common Best Practices")
    sections.push("")
    sections.push("Check for adherence to bundler best practices:")
    sections.push("")
    sections.push("- Efficient caching strategies")
    sections.push("- Proper externals configuration")
    sections.push("- Loader performance (e.g., thread-loader, cache-loader)")
    sections.push("- Plugin optimization")
    sections.push("- Module resolution efficiency")
    sections.push("")

    // Providing additional context
    sections.push("## Providing Additional Context")
    sections.push("")
    sections.push(
      "To get the most accurate analysis, you can provide additional information:"
    )
    sections.push("")
    sections.push("### Build Error Logs")
    sections.push("")
    sections.push("Paste output from:")
    sections.push("```bash")
    sections.push("bin/shakapacker")
    sections.push("# or")
    sections.push("bin/shakapacker-dev-server")
    sections.push("```")
    sections.push("")
    sections.push("### Custom Configuration Files")
    sections.push("")
    sections.push("Include content from your custom config files:")
    sections.push("- `config/webpack/commonWebpackConfig.js`")
    sections.push("- `config/webpack/clientWebpackConfig.js`")
    sections.push("- `config/webpack/serverWebpackConfig.js`")
    sections.push("- `config/webpack/development.js`")
    sections.push("- `config/webpack/production.js`")
    sections.push("")
    sections.push("(Or equivalent rspack files in `config/rspack/` directory)")
    sections.push("")

    // Output format
    sections.push("## Desired Output Format")
    sections.push("")
    sections.push("Please structure your analysis as follows:")
    sections.push("")
    sections.push("1. **Executive Summary**: High-level overview of findings")
    sections.push(
      "2. **Critical Issues**: Problems that will prevent builds from working"
    )
    sections.push(
      "3. **Warnings**: Suboptimal configurations that should be addressed"
    )
    sections.push("4. **Optimizations**: Recommendations for improvement")
    sections.push(
      "5. **Configuration Diffs**: Specific code changes to implement (if applicable)"
    )
    sections.push("")

    // Footer
    sections.push("---")
    sections.push("")
    sections.push("**Generated by Shakapacker Config Exporter**")
    sections.push(`**Bundler**: ${bundler}`)
    sections.push(`**Date**: ${timestamp}`)
    sections.push("")

    return sections.join("\n")
  }

  /**
   * Build a Markdown bullet for an exported config file, attaching a
   * descriptive label when the filename contains recognizable markers.
   * Filenames come from FileWriter.generateFilename
   * ({bundler}-{buildName|env}-{configType}.{ext}), where build names are
   * user-defined, so matching is best-effort and unmatched files are still
   * listed.
   */
  private static describeExportedFile(filename: string): string {
    const lower = filename.toLowerCase()

    let mode: string | null = null
    if (lower.includes("prod")) {
      mode = "production"
    } else if (lower.includes("dev")) {
      mode = "development"
    } else if (lower.includes("test")) {
      mode = "test"
    }
    const modeLabel = mode ? `${mode[0].toUpperCase()}${mode.slice(1)}` : null
    const modeSuffix = mode ? ` for ${mode} mode` : ""

    if (lower.includes("hmr")) {
      const label = modeLabel ? `${modeLabel} (Client, HMR)` : "Client (HMR)"
      return `- **${label}**: \`${filename}\` - Client bundle with Hot Module Replacement${modeSuffix}`
    }
    if (lower.includes("client")) {
      const label = modeLabel ? `${modeLabel} (Client)` : "Client"
      return `- **${label}**: \`${filename}\` - Client bundle${modeSuffix}`
    }
    if (lower.includes("server")) {
      const label = modeLabel ? `${modeLabel} (Server)` : "Server"
      return `- **${label}**: \`${filename}\` - Server-side rendering bundle${modeSuffix}`
    }
    if (lower.includes("-all.")) {
      const label = modeLabel ? `${modeLabel} (All bundles)` : "All bundles"
      return `- **${label}**: \`${filename}\` - Combined client and server configuration${modeSuffix}`
    }
    return `- \`${filename}\``
  }

  /**
   * Generate the filename for the AI prompt file.
   */
  static generatePromptFilename(): string {
    return "AI-ANALYSIS-PROMPT.md"
  }
}
