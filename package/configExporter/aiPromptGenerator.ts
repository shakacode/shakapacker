import { basename } from "path"

/**
 * Generates the content and filename for an AI prompt that accompanies
 * webpack/rspack configuration exports. The prompt helps AI identify issues and
 * suggest optimizations for the bundler configuration. (Writing the file to
 * disk is the caller's responsibility.)
 */
export class AiPromptGenerator {
  /** Filename for the AI prompt written alongside the exported configs. */
  static readonly PROMPT_FILENAME = "AI-ANALYSIS-PROMPT.md"

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
   * @returns Markdown-formatted AI prompt
   */
  static generatePrompt(
    exportedFiles: string[],
    targetDir: string,
    bundler: string,
    options: { includeReactOnRailsContext?: boolean } = {}
  ): string {
    const timestamp = new Date().toISOString()
    const configFiles = AiPromptGenerator.buildConfigFilesSection(exportedFiles)
    const reactOnRailsContext =
      options.includeReactOnRailsContext === false
        ? ""
        : AiPromptGenerator.REACT_ON_RAILS_CONTEXT

    // Only the directory name is included in Context: users are encouraged to
    // paste this prompt into external AI assistants, so the absolute path
    // (which can leak a username or internal layout) is deliberately omitted.
    return `# AI Configuration Analysis Request

This directory contains exported ${bundler} configuration files for analysis.
Please analyze these configurations and provide recommendations.

## Context

- **Bundler**: ${bundler}
- **Exported At**: ${timestamp}
- **Export Directory**: ${basename(targetDir)}

## Configuration Files

${configFiles}

${reactOnRailsContext}## Analysis Objectives

Please analyze the exported configuration files and provide:

### 1. Migration Issues

If this is a migration from webpack to rspack (or vice versa):

- Identify any incompatible plugins or loaders
- Flag deprecated or removed options
- Suggest equivalent replacements
- Check for rspack-specific optimizations that can be enabled

### 2. Build Errors & Warnings

Examine the configuration for common issues that cause build failures:

- Misconfigured loaders or plugins
- Incorrect module resolution settings
- Missing or incorrect output path configurations
- Entry point issues
- DevServer configuration problems

**Note**: If build error logs are provided separately (from \`bin/shakapacker\` or
\`bin/shakapacker-dev-server\`), correlate them with configuration issues.

### 3. Client vs Server Optimization

Compare client and server configurations and recommend:

**Client Bundle Optimizations:**
- Code splitting strategy
- Asset optimization (images, fonts)
- CSS extraction and optimization
- Tree shaking effectiveness
- Bundle size reduction opportunities

**Server Bundle Optimizations:**
- Verify single-chunk output (no code splitting)
- Ensure CSS is not extracted (handled by client)
- Check for proper \`exportOnlyLocals\` for CSS modules
- Validate target environment (web vs node)
- Confirm assets are not emitted during SSR

### 4. Development vs Production Optimization

Compare development and production configurations:

**Development:**
- Fast rebuild times (appropriate devtool setting)
- Hot Module Replacement (HMR) configuration
- Detailed error messages
- DevServer setup

**Production:**
- Minification and optimization
- Source map strategy (balance between debugging and size)
- Cache busting with content hashes
- Compression and asset optimization
- Performance budgets

### 5. Common Best Practices

Check for adherence to bundler best practices:

- Efficient caching strategies
- Proper externals configuration
- Loader performance (e.g., thread-loader, persistent caching via \`cache: { type: 'filesystem' }\`)
- Plugin optimization
- Module resolution efficiency

## Providing Additional Context

To get the most accurate analysis, you can provide additional information:

### Build Error Logs

Paste output from:
\`\`\`bash
bin/shakapacker
# or
bin/shakapacker-dev-server
\`\`\`

### Custom Configuration Files

Include content from your custom config files:
- \`config/webpack/commonWebpackConfig.js\`
- \`config/webpack/clientWebpackConfig.js\`
- \`config/webpack/serverWebpackConfig.js\`
- \`config/webpack/development.js\`
- \`config/webpack/production.js\`

(Or equivalent rspack files in \`config/rspack/\` directory)

## Desired Output Format

Please structure your analysis as follows:

1. **Executive Summary**: High-level overview of findings
2. **Critical Issues**: Problems that will prevent builds from working
3. **Warnings**: Suboptimal configurations that should be addressed
4. **Optimizations**: Recommendations for improvement
5. **Configuration Diffs**: Specific code changes to implement (if applicable)

---

**Generated by Shakapacker Config Exporter**
**Bundler**: ${bundler}
**Date**: ${timestamp}
`
  }

  /**
   * Build the body of the "Configuration Files" section: a bullet per exported
   * file (with a best-effort descriptive label), plus an HMR troubleshooting
   * note when an HMR config is present. Returns a placeholder line when nothing
   * was exported.
   */
  private static buildConfigFilesSection(exportedFiles: string[]): string {
    if (exportedFiles.length === 0) {
      return "No configuration files were exported."
    }

    const fileList = exportedFiles
      .map((file) => AiPromptGenerator.describeExportedFile(file))
      .join("\n")

    const hmrNote = exportedFiles.some((f) => f.toLowerCase().includes("hmr"))
      ? "\n\nThe HMR config is especially useful for troubleshooting dev server, hot reload,\nand live reload issues."
      : ""

    return `The following configuration files are available for analysis:\n\n${fileList}${hmrNote}`
  }

  /**
   * Static React on Rails reference block. Ends with a trailing blank line so it
   * can be interpolated directly before the next section without disturbing the
   * surrounding spacing.
   */
  private static readonly REACT_ON_RAILS_CONTEXT = `## React on Rails Standard Configuration

If this project uses React on Rails, it typically includes these standard configuration files:

1. **\`config/webpack/webpack.config.js\`** (or rspack equivalent)
   - Main entry point that loads environment-specific configs

2. **\`config/webpack/commonWebpackConfig.js\`**
   - Shared configuration between client and server bundles
   - Sets up common loaders, resolve extensions, etc.

3. **\`config/webpack/clientWebpackConfig.js\`**
   - Client-specific configuration
   - Removes server-bundle entry
   - Optimized for browser execution

4. **\`config/webpack/serverWebpackConfig.js\`**
   - Server-side rendering (SSR) configuration
   - Single chunk output (no code splitting)
   - Removes MiniCssExtractPlugin (CSS handled by client)
   - Uses \`css-loader\` with \`exportOnlyLocals: true\`
   - Target can be 'web' or 'node' depending on renderer

### Reference Configuration Examples

For comparison, see the React on Rails webpack/rspack configuration
documentation:

- [Webpack Configuration guide](https://reactonrails.com/docs/core-concepts/webpack-configuration)

The guide demonstrates best practices for React on Rails webpack/rspack configuration.

`

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

    // Check "server" before "hmr"/"client": HMR applies to client bundles, but
    // a build name can combine markers (e.g. "<bundler>-dev-hmr-server.yml"),
    // and such a file is still a server bundle.
    if (lower.includes("server")) {
      const label = modeLabel ? `${modeLabel} (Server)` : "Server"
      return `- **${label}**: \`${filename}\` - Server-side rendering bundle${modeSuffix}`
    }
    if (lower.includes("hmr")) {
      const label = modeLabel ? `${modeLabel} (Client, HMR)` : "Client (HMR)"
      return `- **${label}**: \`${filename}\` - Client bundle with Hot Module Replacement${modeSuffix}`
    }
    if (lower.includes("client")) {
      const label = modeLabel ? `${modeLabel} (Client)` : "Client"
      return `- **${label}**: \`${filename}\` - Client bundle${modeSuffix}`
    }
    if (lower.includes("-all.")) {
      const label = modeLabel ? `${modeLabel} (All bundles)` : "All bundles"
      return `- **${label}**: \`${filename}\` - Combined client and server configuration${modeSuffix}`
    }
    return `- \`${filename}\``
  }
}
