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
- Always link to the PR: `[PR #123](https://github.com/shakacode/shakapacker/pull/123)` - **Note: Shakapacker uses `#` in PR links, unlike React on Rails**
- Always link to the author: `by [username](https://github.com/username)`
- End with a period after the author link
- Additional details can be added after the main entry, using proper indentation for multi-line entries

### Breaking Changes Format

For breaking changes, use this format:

```markdown
- **Breaking**: Description of the breaking change. See [Migration Guide](docs/vX_upgrade.md) for migration instructions. [PR #123](https://github.com/shakacode/shakapacker/pull/123) by [username](https://github.com/username).
```

### Category Organization

Entries should be organized under these section headings. The project uses both standard and custom headings:

**Standard headings** (from keepachangelog.com) - use these for most changes:

- `### Added` - New features
- `### Changed` - Changes to existing functionality
- `### Deprecated` - Deprecation notices
- `### Removed` - Removed features
- `### Fixed` - Bug fixes
- `### Security` - Security-related changes
- `### Improved` - Improvements to existing features

**Custom headings** (project-specific) - use sparingly when standard headings don't fit:

- `### ⚠️ Breaking Changes` - Breaking changes only (Shakapacker uses emoji in heading)
- `### API Improvements` - API changes and improvements
- `### Developer Experience` - Developer workflow improvements
- `### Performance` - Performance improvements

**Prefer standard headings.** Only use custom headings when the change needs more specific categorization.

**Only include section headings that have entries.**

### Version Management

After adding entries, use the rake task to manage version headers:

```bash
bundle exec rake update_changelog
```

This will:

- Add headers for the new version
- Update version diff links at the bottom of the file

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

### For Regular Changelog Updates

1. **ALWAYS fetch latest changes first**:
   - **CRITICAL**: Run `git fetch origin main` to ensure you have the latest commits
   - The workspace may be behind origin/main, causing you to miss recently merged PRs
   - After fetching, use `origin/main` for all comparisons, NOT local `main` branch

2. **Determine the correct version tag to compare against**:
   - First, check the tag dates: `git log --tags --simplify-by-decoration --pretty="format:%ai %d" | head -10`
   - Find the latest version tag and its date
   - Compare origin/main branch date to the tag date
   - If the tag is NEWER than origin/main, it means the branch needs to be updated to include the tag's commits
   - **CRITICAL**: Always use `git log TAG..BRANCH` to find commits that are in the tag but not in the branch, as the tag may be ahead

3. **Check commits and version boundaries**:
   - **IMPORTANT**: Use `origin/main` in all commands below, not local `main`
   - Run `git log --oneline LAST_TAG..origin/main` to see commits since the last release
   - Also check `git log --oneline origin/main..LAST_TAG` to see if the tag is ahead of origin/main
   - If the tag is ahead, entries in "Unreleased" section may actually belong to that tagged version
   - **Extract ALL PR numbers** from commit messages using grep: `git log --oneline LAST_TAG..origin/main | grep -oE "#[0-9]+" | sort -u`
   - For each PR number found, check if it's already in CHANGELOG.md using: `grep "PR #XXX" CHANGELOG.md`
   - Identify which commits contain user-visible changes (look for keywords like "Fix", "Add", "Feature", "Bug", etc.)
   - Extract author information from commit messages
   - **Never ask the user for PR details** - get them from the git history or use WebFetch on the PR URL

4. **Validate** that changes are user-visible (per the criteria above). If not user-visible, skip those commits.

5. **Read the current CHANGELOG.md** to understand the existing structure and formatting.

6. **Determine where entries should go**:
   - If the latest version tag is NEWER than origin/main branch, move entries from "Unreleased" to that version section
   - If origin/main is ahead of the latest tag, add new entries to "Unreleased"
   - Always verify the version date in CHANGELOG.md matches the actual tag date

7. **Add or move entries** to the appropriate section under appropriate category headings.
   - **CRITICAL**: When moving entries from "Unreleased" to a version section, merge them with existing entries under the same category heading
   - **NEVER create duplicate section headings** (e.g., don't create two "### Fixed" sections)
   - If the version section already has a category heading (e.g., "### Fixed"), add the moved entries to that existing section
   - Maintain the category order as defined above

8. **Verify formatting**:
   - Bold description with period
   - Proper PR link
   - Proper author link
   - Consistent with existing entries
   - File ends with a newline character

9. **Run linting** after making changes:

   ```bash
   yarn lint
   ```

10. **Show the user** the added or moved entries and explain what was done.

### For Beta to Non-Beta Version Release

When releasing from beta to a stable version (e.g., v9.1.0-beta.3 → v9.1.0):

1. **Remove all beta version labels** from the changelog:
   - Change `## [v9.1.0-beta.1]`, `## [v9.1.0-beta.2]`, etc. to a single `## [v9.1.0]` section
   - Combine all beta entries into the stable release section

2. **Consolidate duplicate entries**:
   - If bug fixes or changes were made to features introduced in earlier betas, keep only the final state
   - Remove redundant changelog entries for fixes to beta features
   - Keep the most recent/accurate description of each change

3. **Update version diff links** at the bottom to point to the stable version

### For New Beta Version Release

When creating a new beta version, ask the user which approach to take:

**Option 1: Process changes since last beta**

- Only add entries for commits since the previous beta version
- Maintains detailed history of what changed in each beta

**Option 2: Collapse all prior betas into current beta**

- Combine all beta changelog entries into the new beta version
- Removes previous beta version sections
- Cleaner changelog with less version noise

After the user chooses, proceed with that approach.

## Examples

Run this command to see real formatting examples from the codebase:

```bash
grep -A 3 "^### " CHANGELOG.md | head -30
```

### Good Entry Example

```markdown
- **Enhanced error handling for better security and debugging**. [PR #786](https://github.com/shakacode/shakapacker/pull/786) by [justin808](https://github.com/justin808).
  - Path validation now properly reports permission errors instead of silently handling them
  - Module loading errors now include original error context for easier troubleshooting
  - Improved security by only catching ENOENT errors in path resolution, rethrowing permission and access errors
```

### Entry with Sub-bullets Example

```markdown
- **HTTP 103 Early Hints support** for faster asset loading. [PR #722](https://github.com/shakacode/shakapacker/pull/722) by [justin808](https://github.com/justin808). Automatically sends early hints when `early_hints: enabled: true` in `shakapacker.yml`. Works with `append_javascript_pack_tag`/`append_stylesheet_pack_tag`, supports per-controller/action configuration, and includes helpers like `configure_pack_early_hints` and `skip_send_pack_early_hints`. Requires Rails 5.2+ and HTTP/2-capable server. See [Early Hints Guide](docs/early_hints.md).
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
