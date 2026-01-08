import { basename } from "path"
import { ConfigMetadata } from "./types"

/**
 * Generates an AI prompt file for analyzing webpack/rspack configuration exports.
 * The prompt helps AI identify issues and suggest optimizations for the bundler configuration.
 */
export class AiPromptGenerator {
  /**
   * Generate a comprehensive AI analysis prompt based on exported config files.
   *
   * @param exportedFiles - Array of exported config file basenames
   * @param targetDir - Directory where configs were exported
   * @param bundler - The bundler type (webpack or rspack)
   * @param includeReactOnRailsContext - Whether to include React on Rails specific context
   * @returns Markdown-formatted AI prompt
   */
  generatePrompt(
    exportedFiles: string[],
    targetDir: string,
    bundler: string,
    includeReactOnRailsContext = true
  ): string {
    const clientDevFile = exportedFiles.find((f) =>
      f.includes("development-client")
    )
    const serverDevFile = exportedFiles.find((f) =>
      f.includes("development-server")
    )
    const clientProdFile = exportedFiles.find((f) =>
      f.includes("production-client")
    )
    const serverProdFile = exportedFiles.find((f) =>
      f.includes("production-server")
    )

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
    sections.push(`- **Exported At**: ${new Date().toISOString()}`)
    sections.push(`- **Export Directory**: ${targetDir}`)
    sections.push("")

    // Configuration files
    sections.push("## Configuration Files")
    sections.push("")
    sections.push(
      "The following configuration files are available for analysis:"
    )
    sections.push("")

    if (clientDevFile) {
      sections.push(
        `- **Development (Client)**: \`${clientDevFile}\` - Client bundle for development mode`
      )
    }
    if (serverDevFile) {
      sections.push(
        `- **Development (Server)**: \`${serverDevFile}\` - Server-side rendering bundle for development mode`
      )
    }
    if (clientProdFile) {
      sections.push(
        `- **Production (Client)**: \`${clientProdFile}\` - Client bundle for production mode`
      )
    }
    if (serverProdFile) {
      sections.push(
        `- **Production (Server)**: \`${serverProdFile}\` - Server-side rendering bundle for production mode`
      )
    }
    sections.push("")

    // React on Rails context
    if (includeReactOnRailsContext) {
      sections.push("## React on Rails Standard Configuration")
      sections.push("")
      sections.push(
        "This project uses React on Rails, which typically includes these standard configuration files:"
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
        "- [commonWebpackConfig.js](https://github.com/shakacode/react_on_rails/blob/master/spec/dummy/config/webpack/commonWebpackConfig.js)"
      )
      sections.push(
        "- [clientWebpackConfig.js](https://github.com/shakacode/react_on_rails/blob/master/spec/dummy/config/webpack/clientWebpackConfig.js)"
      )
      sections.push(
        "- [serverWebpackConfig.js](https://github.com/shakacode/react_on_rails/blob/master/spec/dummy/config/webpack/serverWebpackConfig.js)"
      )
      sections.push(
        "- [webpack.config.js](https://github.com/shakacode/react_on_rails/blob/master/spec/dummy/config/webpack/webpack.config.js)"
      )
      sections.push("")
      sections.push(
        "**Exported Configuration References (YAML - Coming Soon):**"
      )
      sections.push("")
      sections.push(
        "The React on Rails team is working on providing exported reference configurations"
      )
      sections.push(
        "in YAML format (similar to the files in this directory) for easier comparison."
      )
      sections.push(
        "These will include 10 exported config files (5 for webpack, 5 for rspack):"
      )
      sections.push("")
      sections.push("- Development client (standard build)")
      sections.push("- Development client with HMR (dev server configuration)")
      sections.push("- Development server (SSR)")
      sections.push("- Production client")
      sections.push("- Production server (SSR)")
      sections.push("")
      sections.push(
        "The HMR configs are especially useful for troubleshooting dev server, hot reload,"
      )
      sections.push("and live reload issues.")
      sections.push("")
      sections.push(
        "Track progress at: https://github.com/shakacode/react_on_rails/issues/1862"
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
    sections.push(`**Date**: ${new Date().toISOString()}`)
    sections.push("")

    return sections.join("\n")
  }

  /**
   * Generate filename for the AI prompt.
   */
  generatePromptFilename(): string {
    return "AI-ANALYSIS-PROMPT.md"
  }
}
