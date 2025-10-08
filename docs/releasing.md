# Releasing Shakapacker

This guide is for Shakapacker maintainers who need to publish a new release.

## Prerequisites

1. **Install required tools:**

   ```bash
   bundle install              # Installs gem-release
   yarn global add release-it  # Installs release-it for npm publishing
   ```

2. **Ensure you have publishing access:**

   - npm: You must be a collaborator on the [shakapacker npm package](https://www.npmjs.com/package/shakapacker)
   - RubyGems: You must be an owner of the [shakapacker gem](https://rubygems.org/gems/shakapacker)

3. **Enable 2FA on both platforms:**
   - npm: 2FA is required for publishing
   - RubyGems: 2FA is required for publishing

## Release Process

### 1. Prepare the Release

Before running the release task:

1. Ensure all desired changes are merged to `main` branch
2. Update `CHANGELOG.md` with the new version and release notes
3. Commit the CHANGELOG changes
4. Ensure your working directory is clean (`git status` shows no uncommitted changes)

### 2. Run the Release Task

The automated release task handles the entire release process:

```bash
# For a specific version (e.g., 9.1.0)
rake create_release[9.1.0]

# For a patch version bump (auto-increments)
rake create_release

# Dry run to test without publishing
rake create_release[9.1.0,true]
```

### 3. What the Release Task Does

The `create_release` task automatically:

1. **Pulls latest changes** from the repository
2. **Bumps version numbers** in:
   - `lib/shakapacker/version.rb` (Ruby gem version)
   - `package.json` (npm package version - converted from Ruby format)
3. **Publishes to npm:**
   - Prompts for npm OTP (2FA code)
   - Creates git tag
   - Pushes to GitHub
4. **Publishes to RubyGems:**
   - Prompts for RubyGems OTP (2FA code)
5. **Updates spec/dummy lockfiles:**
   - Runs `bundle install` to update `Gemfile.lock`
   - Runs `npm install` to update `package-lock.json` and `yarn.lock`
6. **Commits and pushes lockfile changes** automatically

### 4. Version Format

**Important:** Use Ruby gem version format (no dashes):

- ✅ Correct: `9.1.0`, `9.2.0.beta.1`
- ❌ Wrong: `9.1.0-beta.1`

The task automatically converts Ruby gem format to npm semver format:

- Ruby: `9.2.0.beta.1` → npm: `9.2.0-beta.1`

### 5. During the Release

1. When prompted for **npm OTP**, enter your 2FA code from your authenticator app
2. Accept defaults for release-it options
3. When prompted for **RubyGems OTP**, enter your 2FA code
4. The script will automatically commit and push lockfile updates

### 6. After Release

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

If you see uncommitted changes to `spec/dummy/package-lock.json` or `spec/dummy/yarn.lock` after a release, this means:

1. The release was successful but the lockfile commit step may have failed
2. **Solution:** Manually commit these files:
   ```bash
   git add spec/dummy/package-lock.json spec/dummy/yarn.lock
   git commit -m 'Update spec/dummy lockfiles after release'
   git push
   ```

### Failed npm or RubyGems Publish

If publishing fails partway through:

1. Check which step failed (npm or RubyGems)
2. If npm failed: Fix the issue and manually run `npm publish`
3. If RubyGems failed: Fix the issue and manually run `gem release`
4. Then manually update and commit spec/dummy lockfiles

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
