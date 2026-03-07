# Releasing Shakapacker

This guide is for Shakapacker maintainers who need to publish a new release.

## Prerequisites

1. **Install required tools:**

   ```bash
   bundle install              # Installs gem-release
   yarn global add release-it  # Installs release-it for npm publishing
   gh --version                # Ensure GitHub CLI is installed for GitHub releases
   ```

2. **Ensure you have publishing access:**
   - npm: You must be a collaborator on the [shakapacker npm package](https://www.npmjs.com/package/shakapacker)
   - RubyGems: You must be an owner of the [shakapacker gem](https://rubygems.org/gems/shakapacker)

3. **Enable 2FA on both platforms:**
   - npm: 2FA is required for publishing
   - RubyGems: 2FA is required for publishing
4. **Authenticate GitHub CLI:**
   - Run `gh auth login` and ensure your account/token has write access to this repository

## Release Process

### 1. Prepare the Release

Before running the release task:

1. Ensure all desired changes are merged to `main` branch
2. Ensure your working directory is clean (`git status` shows no uncommitted changes)

### 2. Run the Release Task

The automated release task handles the entire release process:

```bash
# For a specific version (e.g., 9.1.0)
bundle exec rake "create_release[9.1.0]"

# For a beta release (note: use period, not dash)
bundle exec rake "create_release[9.2.0.beta.1]"  # Creates npm package 9.2.0-beta.1

# For a release candidate
bundle exec rake "create_release[9.6.0.rc.0]"

# Auto-calculate next prerelease and confirm before publishing
bundle exec rake "create_prerelease[9.6.0]"      # defaults to rc -> 9.6.0.rc.0 or 9.6.0.rc.1, etc.
bundle exec rake "create_prerelease[9.6.0,rc]"   # -> 9.6.0.rc.0 or 9.6.0.rc.1, etc.
bundle exec rake "create_prerelease[9.6.0,beta]" # -> 9.6.0.beta.0 or 9.6.0.beta.1, etc.

# For a patch version bump (auto-increments)
bundle exec rake create_release  # prompts to confirm computed patch version

# Dry run to test without publishing
bundle exec rake "create_release[9.1.0,true]"

# Override version policy checks (monotonic + changelog/bump consistency)
RELEASE_VERSION_POLICY_OVERRIDE=true bundle exec rake "create_release[9.1.0]"
bundle exec rake "create_release[9.1.0,false,true]"
```

Dry runs use a temporary git worktree so version bumps and installs do not modify your current checkout.

`create_release` and `create_prerelease` validate release-version policy before publishing:
- Target version must be greater than the latest tagged release.
- If the target changelog section exists, it maps to expected bump type:
  - Breaking changes => major bump
  - Added features => minor bump
  - Otherwise => patch bump

Use override only when needed:
- `RELEASE_VERSION_POLICY_OVERRIDE=true`
- Or task arg override (`create_release[..., ..., true]`, `create_prerelease[..., ..., ..., true]`)

### 3. What the Release Task Does

The `create_release` task automatically:

1. **Validates release prerequisites**:
   - Verifies npm authentication
2. **Pulls latest changes** from the repository
3. **Bumps version numbers** in:
   - `lib/shakapacker/version.rb` (Ruby gem version)
   - `package.json` (npm package version - converted from Ruby format)
4. **Publishes to npm:**
   - Prompts for npm OTP (2FA code)
   - Creates git tag
   - Pushes to GitHub
5. **Publishes to RubyGems:**
   - Prompts for RubyGems OTP (2FA code)
6. **Updates spec/dummy lockfiles:**
   - Runs `bundle install` to update `Gemfile.lock`
   - Runs `npm install` to update `package-lock.json` (yarn.lock may also be updated for multi-package-manager compatibility testing)
7. **Commits and pushes lockfile changes** automatically

### 4. Sync GitHub Release (Optional, After Publish)

If you want GitHub Releases, do that as a separate step after publishing:

1. Run `bundle exec rake update_changelog`
2. Update `CHANGELOG.md` with the published version section
   - For prerelease entries, use npm semver header format with dashes, for example `## [v9.6.0-rc.1]`
3. Commit `CHANGELOG.md`
4. Run:

```bash
# Stable
bundle exec rake "sync_github_release[9.6.0]"

# Prerelease
bundle exec rake "sync_github_release[9.6.0.rc.1]"
```

`sync_github_release` reads release notes from the matching `CHANGELOG.md` section and creates/updates the GitHub release for the corresponding tag.
Before syncing, it prompts for confirmation that your local branch is up to date.

### 5. Version Format

**Important:** Use Ruby gem version format (no dashes):

- ✅ Correct: `9.1.0`, `9.2.0.beta.1`, `9.0.0.rc.2`
- ❌ Wrong: `9.1.0-beta.1`, `9.0.0-rc.2`

The task automatically converts Ruby gem format to npm semver format:

- Ruby: `9.2.0.beta.1` → npm: `9.2.0-beta.1`
- Ruby: `9.0.0.rc.2` → npm: `9.0.0-rc.2`

**Examples:**

```bash
# Regular release
bundle exec rake "create_release[9.1.0]"  # Gem: 9.1.0, npm: 9.1.0

# Beta release
bundle exec rake "create_release[9.2.0.beta.1]"  # Gem: 9.2.0.beta.1, npm: 9.2.0-beta.1

# Release candidate
bundle exec rake "create_release[10.0.0.rc.1]"  # Gem: 10.0.0.rc.1, npm: 10.0.0-rc.1

# Auto-next prerelease (recommended)
bundle exec rake "create_prerelease[10.0.0,rc]"  # picks rc.0 then rc.1, etc., with confirmation
```

The `create_prerelease` task defaults to `rc` if prerelease type is omitted. Use `beta` explicitly when needed.

### 6. During the Release

1. When prompted for **npm OTP**, enter your 2FA code from your authenticator app
2. Accept defaults for release-it options
3. When prompted for **RubyGems OTP**, enter your 2FA code
4. If using patch auto-bump (`create_release` with no version), confirm the computed patch version when prompted
5. If using `create_prerelease`, confirm the computed next prerelease version when prompted
6. The script will automatically commit and push lockfile updates

### 7. After Release

1. Verify the release on:
   - [npm](https://www.npmjs.com/package/shakapacker)
   - [RubyGems](https://rubygems.org/gems/shakapacker)
   - [GitHub releases](https://github.com/shakacode/shakapacker/releases)

2. Check that the lockfile commit was pushed:

   ```bash
   git log --oneline -5
   # Should see "Update spec/dummy lockfiles after release"
   ```

3. Announce the release (if appropriate):
   - Post in relevant Slack/Discord channels
   - Tweet about major releases
   - Update documentation if needed

## Troubleshooting

### Uncommitted Changes After Release

If you see uncommitted changes to lockfiles after a release, this means:

1. The release was successful but the lockfile commit step may have failed
2. **Solution:** Manually commit these files:
   ```bash
   git add spec/dummy/Gemfile.lock spec/dummy/package-lock.json spec/dummy/yarn.lock
   git commit -m 'Update spec/dummy lockfiles after release'
   git push
   ```

### Failed npm or RubyGems Publish

If publishing fails partway through:

1. Check which step failed (npm or RubyGems)
2. If npm failed: Fix the issue and manually run `npm publish`
3. If RubyGems failed: Fix the issue and manually run `gem release`
4. Then manually update and commit spec/dummy lockfiles

### GitHub Release Sync Fails

If package publishing succeeds but `sync_github_release` fails:

1. Fix GitHub auth (`gh auth login`) or permissions
2. Ensure `CHANGELOG.md` has matching header `## [vX.Y.Z...]` (npm format for prereleases)
3. Rerun only:

   ```bash
   bundle exec rake "sync_github_release[<gem_version>]"
   ```

### Wrong Version Format

If you accidentally use npm format (with dashes):

1. The gem will be created with an invalid version
2. **Solution:** Don't push the changes, reset your branch:
   ```bash
   git reset --hard HEAD
   ```
3. Re-run with correct Ruby gem format

## Manual Release Steps

If you need to release manually (not recommended):

1. **Bump version:**

   ```bash
   gem bump --version 9.1.0
   bundle install
   ```

2. **Publish to npm:**

   ```bash
   release-it 9.1.0 --npm.publish
   ```

3. **Publish to RubyGems:**

   ```bash
   gem release
   ```

4. **Update lockfiles:**
   ```bash
   cd spec/dummy
   bundle install
   npm install
   cd ../..
   git add spec/dummy/Gemfile.lock spec/dummy/package-lock.json spec/dummy/yarn.lock
   git commit -m 'Update spec/dummy lockfiles after release'
   git push
   ```

## Questions?

If you encounter issues not covered here, please:

1. Check the [CONTRIBUTING.md](../CONTRIBUTING.md) guide
2. Ask in the maintainers channel
3. Update this documentation for future releases
