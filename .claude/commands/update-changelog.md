# Update Changelog

You are helping to add an entry to the CHANGELOG.md file for the Shakapacker project.

## Critical Requirements

1. **User-visible changes only**: Only add changelog entries for user-visible changes:
   - New features
   - Bug fixes
   - Breaking changes
   - Deprecations
   - Performance improvements
   - Security fixes
   - Changes to public APIs or configuration options

2. **Do NOT add entries for**:
   - Linting fixes
   - Code formatting
   - Internal refactoring
   - Test updates
   - Documentation fixes (unless they fix incorrect docs about behavior)
   - CI/CD changes

## Formatting Requirements

### Entry Format

Each changelog entry MUST follow this exact format:

```markdown
- **Bold description of change**. [PR #123](https://github.com/shakacode/shakapacker/pull/123) by [username](https://github.com/username). Optional additional context or details.
```

**Important formatting rules**:

- Start with a dash and space: `- `
- Use **bold** for the main description
- End the bold description with a period before the link
- Always link to the PR: `[PR #123](https://github.com/shakacode/shakapacker/pull/123)`
- Always link to the author: `by [username](https://github.com/username)`
- End with a period after the author link
- Additional details can be added after the main entry, using proper indentation for multi-line entries

### Breaking Changes Format

For breaking changes, use this format:

```markdown
- **Breaking**: Description of the breaking change. See [Migration Guide](docs/vX_upgrade.md) for migration instructions. [PR #123](https://github.com/shakacode/shakapacker/pull/123) by [username](https://github.com/username).
```

### Category Organization

Entries should be organized under these section headings in order of priority:

1. `### ⚠️ Breaking Changes` - Breaking changes only
2. `### Added` - New features
3. `### Changed` - Changes to existing functionality
4. `### Improved` - Improvements to existing features
5. `### Security` - Security-related changes
6. `### Fixed` - Bug fixes
7. `### Deprecated` - Deprecation notices
8. `### Removed` - Removed features

**Only include section headings that have entries.**

### Version Links

After adding an entry to the `## [Unreleased]` section, ensure the version diff links at the bottom of the file are correct.

The format at the bottom should be:

```markdown
[Unreleased]: https://github.com/shakacode/shakapacker/compare/v9.3.0...main
[v9.3.0]: https://github.com/shakacode/shakapacker/compare/v9.2.0...v9.3.0
```

When a new version is released:

1. Change `[Unreleased]` heading to `## [vX.Y.Z] - Month Day, Year`
2. Add a new `## [Unreleased]` section at the top
3. Update the `[Unreleased]` link to compare from the new version
4. Add a new version link for the released version

## Process

1. **Ask for details** if not provided:
   - What is the PR number?
   - What is the GitHub username of the author?
   - What category does this change belong to?
   - What is a concise description of the change?
   - Is this a breaking change?

2. **Validate** that the change is user-visible (per the criteria above). If it's not user-visible, politely explain that it doesn't need a changelog entry.

3. **Read the current CHANGELOG.md** to understand the existing structure and formatting.

4. **Add the entry** to the `## [Unreleased]` section under the appropriate category heading.

5. **Verify formatting**:
   - Bold description with period
   - Proper PR link
   - Proper author link
   - Consistent with existing entries
   - File ends with a newline character

6. **Run linting** after making changes:

   ```bash
   yarn lint
   ```

7. **Verify the changes** by showing the user the added entry.

## Examples

### Good Entry Example

```markdown
- **Enhanced error handling for better security and debugging**. [PR #786](https://github.com/shakacode/shakapacker/pull/786) by [justin808](https://github.com/justin808).
  - Path validation now properly reports permission errors instead of silently handling them
  - Module loading errors now include original error context for easier troubleshooting
  - Improved security by only catching ENOENT errors in path resolution, rethrowing permission and access errors
```

### Breaking Change Example

```markdown
- **Breaking: SWC default configuration now uses `loose: false`**. [PR #658](https://github.com/shakacode/shakapacker/pull/658) by [justin808](https://github.com/justin808). See [v9 Upgrade Guide - SWC Loose Mode](./docs/v9_upgrade.md#swc-loose-mode-breaking-change-v910) for migration details.
```

## Additional Notes

- Keep descriptions concise but informative
- Focus on the "what" and "why", not the "how"
- Use past tense for the description
- Be consistent with existing formatting in the changelog
- Always ensure the file ends with a trailing newline
