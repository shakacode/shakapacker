require_relative File.join("..", "lib", "shakapacker", "utils", "version_syntax_converter")
require_relative File.join("..", "lib", "shakapacker", "utils", "misc")
require "rubygems/version"
require "shellwords"
require "open3"
require "tempfile"
require "tmpdir"

class RaisingMessageHandler
  def add_error(error)
    raise error
  end
end

def ensure_clean_worktree!
  Shakapacker::Utils::Misc.uncommitted_changes?(RaisingMessageHandler.new)
end

def github_repo_slug(gem_root)
  origin_url, status = Open3.capture2e("git", "-C", gem_root, "remote", "get-url", "origin")
  origin_url = origin_url.strip
  abort "❌ Unable to determine git origin URL for GitHub release checks.\n\n#{origin_url}" unless status.success?

  match = origin_url.match(%r{github\.com[:/](?<repo>[^/]+/[^/]+?)(?:\.git)?\z})
  abort "❌ Unable to determine GitHub repository from origin URL #{origin_url.inspect}" unless match

  match[:repo]
end

def verify_npm_auth(registry_url = "https://registry.npmjs.org/")
  display_registry_url = registry_url
  begin
    result, status = Open3.capture2e("npm", "whoami", "--registry", registry_url)
  rescue Errno::ENOENT
    abort "❌ npm is not installed or not available on PATH. Install npm and retry."
  end
  unless status.success?
    puts "⚠️  NPM authentication required!"
    puts "Please run: npm login --registry #{display_registry_url}"
    puts ""
    begin
      login_success = system("npm", "login", "--registry", registry_url)
    rescue Errno::ENOENT
      abort "❌ npm is not installed or not available on PATH. Install npm and retry."
    end
    abort "❌ NPM login failed! Please authenticate with npm before running the release." unless login_success

    begin
      result, status = Open3.capture2e("npm", "whoami", "--registry", registry_url)
    rescue Errno::ENOENT
      abort "❌ npm is not installed or not available on PATH. Install npm and retry."
    end
    abort "❌ NPM login failed! Please authenticate with npm before running the release.\n\n#{result}" unless status.success?
  end
  puts "✓ Logged in to NPM as: #{result.strip}"
end

def verify_gh_auth(gem_root:)
  begin
    result, status = Open3.capture2e("gh", "auth", "status")
  rescue Errno::ENOENT
    abort "❌ GitHub CLI is not installed or not available on PATH. Install `gh` and retry."
  end
  unless status.success?
    abort "❌ GitHub CLI authentication required! Run `gh auth login` and retry.\n\n#{result}"
  end

  repo_slug = github_repo_slug(gem_root)
  permissions_result, status = Open3.capture2e("gh", "api", "repos/#{repo_slug}", "--jq", ".permissions.push")
  permissions_result = permissions_result.strip
  unless status.success?
    abort "❌ GitHub CLI authenticated, but failed to verify write access to #{repo_slug}.\n\n#{permissions_result}"
  end
  unless permissions_result == "true"
    abort "❌ GitHub CLI authenticated, but your account/token does not have write access to #{repo_slug}."
  end

  puts "✓ GitHub CLI authenticated with write access to #{repo_slug}"
end

def current_gem_version(gem_root)
  version_file = File.join(gem_root, "lib", "shakapacker", "version.rb")
  content = File.read(version_file)
  match = content.match(/VERSION = "([^"]+)"/)
  abort "❌ Unable to read current gem version from #{version_file}" unless match

  match[1]
end

def target_gem_version(gem_root:, requested_gem_version:)
  version = requested_gem_version.to_s.strip
  return version unless version.empty?

  current_version = current_gem_version(gem_root)
  match = current_version.match(/\A(\d+)\.(\d+)\.(\d+)\z/)
  unless match
    abort "❌ Automatic patch bumps require the current version to use major.minor.patch format. Pass an explicit version instead."
  end

  major, minor, patch = match.captures.map(&:to_i)
  "#{major}.#{minor}.#{patch + 1}"
end

def prerelease_gem_version?(gem_version)
  gem_version.match?(/\A\d+\.\d+\.\d+\.(beta|rc)\.\d+\z/)
end

def npm_dist_tag_for_version(npm_version)
  prerelease_part = npm_version.to_s.split("-", 2)[1]
  return "latest" if prerelease_part.nil? || prerelease_part.empty?

  prerelease_part.split(".", 2).first
end

def validate_requested_gem_version!(requested_gem_version)
  return if requested_gem_version.empty?
  return if requested_gem_version.match?(/\A\d+\.\d+\.\d+(\.(beta|rc)\.\d+)?\z/)

  abort "❌ gem_version must be in RubyGems format (no dashes), e.g. 9.6.0 or 9.6.0.rc.0. Got: #{requested_gem_version.inspect}"
end

def parse_gem_version_components(gem_version)
  match = gem_version.to_s.strip.match(/\A(\d+)\.(\d+)\.(\d+)(?:\.(beta|rc)\.(\d+))?\z/)
  abort "❌ Unsupported gem version format for release validation: #{gem_version.inspect}" unless match

  {
    major: match[1].to_i,
    minor: match[2].to_i,
    patch: match[3].to_i,
    prerelease_type: match[4],
    prerelease_index: match[5]&.to_i
  }
end

def parse_release_tag_to_gem_version(tag)
  stable_match = tag.match(/\Av(\d+\.\d+\.\d+)\z/)
  return stable_match[1] if stable_match

  prerelease_match = tag.match(/\Av(\d+\.\d+\.\d+)-(beta|rc)\.(\d+)\z/)
  return "#{prerelease_match[1]}.#{prerelease_match[2]}.#{prerelease_match[3]}" if prerelease_match

  nil
end

def tagged_release_gem_versions(gem_root, fetch_tags: true)
  if fetch_tags
    fetch_output, fetch_status = Open3.capture2e("git", "-C", gem_root, "fetch", "--tags", "--quiet")
    abort "❌ Unable to fetch tags for version policy validation.\n\n#{fetch_output.strip}" unless fetch_status.success?
  end

  tags_output, tags_status = Open3.capture2e("git", "-C", gem_root, "tag", "-l", "v*")
  abort "❌ Unable to list git tags for version policy validation.\n\n#{tags_output.strip}" unless tags_status.success?

  tags_output.lines.map(&:strip).filter_map { |tag| parse_release_tag_to_gem_version(tag) }.uniq
end

def version_bump_type(previous_stable_gem_version:, target_gem_version:)
  previous = parse_gem_version_components(previous_stable_gem_version)
  target = parse_gem_version_components(target_gem_version)

  return :major if target[:major] > previous[:major]
  return :minor if target[:major] == previous[:major] && target[:minor] > previous[:minor]
  return :patch if target[:major] == previous[:major] && target[:minor] == previous[:minor] && target[:patch] > previous[:patch]

  :none
end

def expected_bump_type_from_changelog_section(changelog_section)
  section = changelog_section.to_s
  # Keep bump inference conservative to avoid prose-triggered false positives.
  return :major if section.match?(/^###\s+(?:⚠️\s*)?Breaking(?:\s+Changes?)?\b/i)
  return :minor if section.match?(/^###\s+(Added|New\s+Features?|Features?|Enhancements?)\b/i)
  return :patch if section.match?(/^###\s+(Fixed|Fixes|Bug\s+Fixes?|Security|Improved|Deprecated)\b/i)

  nil
end

def version_policy_override_enabled?(override_flag)
  Shakapacker::Utils::Misc.object_to_boolean(override_flag) ||
    Shakapacker::Utils::Misc.object_to_boolean(ENV["RELEASE_VERSION_POLICY_OVERRIDE"])
end

def handle_version_policy_violation!(message:, allow_override:)
  if allow_override
    normalized = message.sub(/\A❌\s*/, "")
    puts "⚠️ VERSION POLICY OVERRIDE enabled: #{normalized}"
    return
  end

  abort message
end

def validate_release_version_policy!(gem_root:, target_gem_version:, allow_override:, fetch_tags: true)
  tagged_versions = tagged_release_gem_versions(gem_root, fetch_tags: fetch_tags)
  latest_tagged_version = tagged_versions.max_by { |version| Gem::Version.new(version) }

  if latest_tagged_version && Gem::Version.new(target_gem_version) <= Gem::Version.new(latest_tagged_version)
    handle_version_policy_violation!(
      message: "❌ Requested version #{target_gem_version} must be greater than latest tagged version #{latest_tagged_version}.",
      allow_override: allow_override
    )
  end

  if prerelease_gem_version?(target_gem_version) && latest_tagged_version
    target_components = parse_gem_version_components(target_gem_version)
    latest_components = parse_gem_version_components(latest_tagged_version)
    same_release_base = target_components[:major] == latest_components[:major] &&
      target_components[:minor] == latest_components[:minor] &&
      target_components[:patch] == latest_components[:patch]
    # Any prerelease-to-prerelease move on the same base (for example rc.0 -> rc.1 or beta.0 -> rc.0)
    # intentionally skips changelog bump-shape inference; the base bump was validated on first prerelease.
    return if same_release_base && prerelease_gem_version?(latest_tagged_version)
  end

  latest_stable_version = tagged_versions.reject { |version| prerelease_gem_version?(version) }
    .max_by { |version| Gem::Version.new(version) }
  return unless latest_stable_version

  actual_bump_type = version_bump_type(previous_stable_gem_version: latest_stable_version, target_gem_version: target_gem_version)
  if actual_bump_type == :none
    handle_version_policy_violation!(
      message: "❌ Requested version #{target_gem_version} is not a major/minor/patch bump over latest stable #{latest_stable_version}.",
      allow_override: allow_override
    )
    # With override enabled, this bump shape is intentionally accepted; skip changelog bump matching.
    return if allow_override
  end

  if prerelease_gem_version?(target_gem_version)
    puts "ℹ️ VERSION POLICY: Skipping changelog bump-consistency check for prerelease #{target_gem_version}."
    return
  end

  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(target_gem_version)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  changelog_section = extract_changelog_section(changelog_path: changelog_path, npm_version: npm_version)
  changelog_source = "v#{npm_version}"

  unless changelog_section
    puts "ℹ️ VERSION POLICY: No changelog content found for v#{npm_version}; skipping changelog bump-consistency check."
    return
  end

  expected_bump_type = expected_bump_type_from_changelog_section(changelog_section)
  unless expected_bump_type
    puts "ℹ️ VERSION POLICY: CHANGELOG section #{changelog_source} does not declare bump level; skipping changelog bump-consistency check."
    return
  end
  return if actual_bump_type == expected_bump_type

  handle_version_policy_violation!(
    message: "❌ Version bump mismatch for #{target_gem_version}: CHANGELOG section #{changelog_source} implies #{expected_bump_type}, but version bump is #{actual_bump_type} from #{latest_stable_version}.",
    allow_override: allow_override
  )
end

def extract_latest_changelog_version(gem_root:)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  return nil unless File.exist?(changelog_path)

  converter = Shakapacker::Utils::VersionSyntaxConverter.new
  File.readlines(changelog_path).each do |line|
    # Match versioned headers like ## [v9.6.0] or ## [v9.6.0-rc.1], skip ## [Unreleased]
    match = line.match(/^## \[v([^\]]+)\]/)
    next unless match

    npm_version = match[1]
    gem_version = converter.npm_to_rubygem(npm_version)
    return gem_version if gem_version
  end

  nil
end

def warn_changelog_missing(gem_root:, npm_version:)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  section = extract_changelog_section(changelog_path: changelog_path, npm_version: npm_version)
  return if section

  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "WARNING: No CHANGELOG.md section found for v#{npm_version}."
  puts "Consider running /update-changelog to add entries before releasing."
  puts "sync_github_release will fail without a changelog section."
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
end

def sync_github_release_after_publish(gem_root:, gem_version:, dry_run:)
  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(gem_version)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  section = extract_changelog_section(changelog_path: changelog_path, npm_version: npm_version)

  unless section
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Skipping GitHub release: no CHANGELOG.md section for v#{npm_version}."
    puts "After adding the changelog section, run:"
    puts "bundle exec rake \"sync_github_release[#{gem_version}]\""
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    return
  end

  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "Creating GitHub release for v#{npm_version}"
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"

  verify_gh_auth(gem_root: gem_root)
  release_context = prepare_github_release_context(
    gem_root: gem_root,
    npm_version: npm_version,
    gem_version: gem_version
  )
  publish_or_update_github_release(gem_root: gem_root, release_context: release_context, dry_run: dry_run)
end

def extract_changelog_section(changelog_path:, npm_version:)
  lines = File.readlines(changelog_path)
  section_header = /^## \[v#{Regexp.escape(npm_version)}\]/
  start_index = lines.index { |line| line.match?(section_header) }
  return nil unless start_index

  end_index = ((start_index + 1)...lines.length).find { |idx| lines[idx].start_with?("## [") } || lines.length
  # Skip the version header line itself — GitHub releases display the title separately.
  lines[(start_index + 1)...end_index].join.strip
end

def prepare_github_release_context(gem_root:, npm_version:, gem_version:)
  prerelease = prerelease_gem_version?(gem_version)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  notes = extract_changelog_section(changelog_path: changelog_path, npm_version: npm_version)
  unless notes
    format_hint = if prerelease
      " For prerelease versions, CHANGELOG headers must use npm semver format, e.g. `## [v#{npm_version}]`."
    end
    abort "❌ Could not find `## [v#{npm_version}]` in CHANGELOG.md.#{format_hint} Add that section and retry."
  end

  {
    notes: notes,
    prerelease: prerelease,
    tag: "v#{npm_version}",
    title: "v#{npm_version}"
  }
end

def changelog_dirty?(gem_root:)
  changes_output, status = Open3.capture2e("git", "-C", gem_root, "status", "--porcelain", "--", "CHANGELOG.md")
  stripped = changes_output.strip
  abort "❌ Unable to check CHANGELOG.md status\n\n#{stripped}" unless status.success?
  !stripped.empty?
end

def ensure_changelog_committed!(gem_root:)
  return unless changelog_dirty?(gem_root: gem_root)
  abort "❌ CHANGELOG.md has uncommitted changes. Commit or stash CHANGELOG.md before running sync_github_release."
end

def ensure_git_tag_exists!(gem_root:, tag:)
  fetch_output, fetch_status = Open3.capture2e("git", "-C", gem_root, "fetch", "--tags", "--quiet")
  unless fetch_status.success?
    abort "❌ Unable to fetch git tags before verifying #{tag.inspect}.\n\n#{fetch_output.strip}"
  end

  tag_ref = "refs/tags/#{tag}"
  tag_exists = system("git", "-C", gem_root, "rev-parse", "--verify", "--quiet", tag_ref, out: File::NULL, err: File::NULL)
  abort "❌ Unable to run git to verify tag #{tag.inspect}. Ensure git is installed and on PATH." if tag_exists.nil?
  return if tag_exists

  abort "❌ Git tag #{tag.inspect} was not found locally or remotely. Verify the tag exists before syncing GitHub release."
end

def github_release_command(gem_root: nil, release_context:, notes_file_path:, probe_existing: true)
  create_command = ["gh", "release", "create", release_context[:tag], "--verify-tag", "--title", release_context[:title],
                    "--notes-file", notes_file_path]
  create_command << "--prerelease" if release_context[:prerelease]
  return create_command unless probe_existing

  abort "❌ Internal error: github_release_command requires gem_root when probe_existing is true." unless gem_root

  release_exists = system("gh", "release", "view", release_context[:tag], chdir: gem_root, out: File::NULL, err: File::NULL)
  abort "❌ Unable to run `gh`. Ensure GitHub CLI is installed and on PATH." if release_exists.nil?

  if release_exists
    # `gh release edit` accepts `--prerelease=true|false`; there is no `--no-prerelease` flag.
    ["gh", "release", "edit", release_context[:tag], "--title", release_context[:title], "--notes-file", notes_file_path,
     "--prerelease=#{release_context[:prerelease]}"]
  else
    create_command
  end
end

def publish_or_update_github_release(gem_root:, release_context:, dry_run:)
  # Keep this check before the dry-run return so preflight runs catch missing tags.
  ensure_git_tag_exists!(gem_root: gem_root, tag: release_context[:tag])

  if dry_run
    preview_command = github_release_command(
      release_context: release_context,
      notes_file_path: "release-notes-file",
      probe_existing: false
    )
    puts "DRY RUN: Would create or update GitHub release #{release_context[:tag]}#{release_context[:prerelease] ? ' (prerelease)' : ''}"
    puts "DRY RUN: Would run: #{Shellwords.join(preview_command)}"
    puts "DRY RUN: If the release already exists, the live run will use `gh release edit` instead."
    return
  end

  Tempfile.create(["shakapacker-release-notes-", ".md"]) do |tmp|
    tmp.write(release_context[:notes])
    tmp.flush

    release_command = github_release_command(
      gem_root: gem_root,
      release_context: release_context,
      notes_file_path: tmp.path
    )

    puts "Publishing GitHub release #{release_context[:tag]}#{release_context[:prerelease] ? ' (prerelease)' : ''}"
    success = system(*release_command, chdir: gem_root)
    abort "❌ Failed to publish GitHub release #{release_context[:tag]}." unless success
  end
end

def with_release_checkout(gem_root:, dry_run:)
  return yield(gem_root) unless dry_run

  Dir.mktmpdir("shakapacker-release-dry-run") do |tmpdir|
    worktree_dir = File.join(tmpdir, "worktree")
    escaped_worktree_dir = Shellwords.escape(worktree_dir)

    # Dry runs should exercise the release flow without dirtying the maintainer's checkout.
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git worktree add --detach #{escaped_worktree_dir} HEAD")
    begin
      yield(worktree_dir)
    ensure
      Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git worktree remove --force #{escaped_worktree_dir}")
    end
  end
end

def confirm_or_abort!(prompt)
  return if Shakapacker::Utils::Misc.object_to_boolean(ENV["AUTO_CONFIRM"])

  print "#{prompt} [y/N]: "
  answer = $stdin.gets.to_s.strip.downcase
  abort "❌ Aborted by user." unless %w[y yes].include?(answer)
end

def release_staged_files
  [
    "lib/shakapacker/version.rb",
    "Gemfile.lock",
    "spec/dummy/Gemfile.lock",
    "spec/dummy/yarn.lock",
    "spec/dummy/package-lock.json"
  ]
end

def print_release_summary(release_result)
  released_gem_version = release_result[:released_gem_version]
  released_npm_version = release_result[:released_npm_version]
  dry_run = release_result[:dry_run]
  changelog_section_found = release_result[:changelog_section_found]
  staged_files = release_result[:staged_files] || []

  puts "\n#{'=' * 80}"
  puts(dry_run ? "DRY RUN COMPLETE" : "RELEASE COMPLETE!")
  puts "=" * 80

  if dry_run
    puts "Version would be bumped to: #{released_gem_version} (gem) / #{released_npm_version} (npm)"
    puts "\nFiles that would be updated:"
    staged_files.each { |file| puts "  - #{file}" }
    puts "  - package.json (updated by release-it)"
    puts "\nTo actually release, run: rake \"release[#{released_gem_version}]\""
    return
  end

  puts "Published to npmjs.org:"
  puts "  - shakapacker@#{released_npm_version}"
  puts ""
  puts "Ruby Gem (RubyGems.org):"
  puts "  - shakapacker #{released_gem_version}"
  puts ""

  if changelog_section_found
    puts "Changelog: ✓ CHANGELOG.md section found for v#{released_npm_version}"
    return
  end

  puts "Next steps:"
  puts "  1. Add CHANGELOG.md entries for v#{released_npm_version}."
  puts "  2. Run bundle exec rake \"sync_github_release[#{released_gem_version}]\""
end

def perform_release(
  gem_version:,
  dry_run:,
  check_uncommitted: true,
  allow_version_policy_override: false,
  fetch_tags_for_policy: true
)
  ensure_clean_worktree! if check_uncommitted
  gem_root = File.expand_path("..", __dir__)
  # This is filled inside the release checkout block and used for the post-release GitHub sync.
  released_gem_version = nil
  released_npm_version = nil
  changelog_section_found = false
  staged_files = release_staged_files

  unless dry_run
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "PRE-FLIGHT CHECKS"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    verify_npm_auth
    verify_gh_auth(gem_root: gem_root)
  end

  requested_gem_version = gem_version.to_s.strip
  validate_requested_gem_version!(requested_gem_version)

  with_release_checkout(gem_root: gem_root, dry_run: dry_run) do |release_root|
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "git pull --rebase") unless dry_run

    # The release root may change after `git pull --rebase`, so patch-bump inference must happen after that step.
    resolved_target_gem_version = target_gem_version(gem_root: release_root, requested_gem_version: requested_gem_version)

    # Warn if changelog section is missing for the target version.
    target_npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(resolved_target_gem_version)
    warn_changelog_missing(gem_root: release_root, npm_version: target_npm_version)
    # Non-dry-run already executed `git pull --rebase`, so tag fetching here is only needed for dry-run flows.
    should_fetch_tags_for_policy = fetch_tags_for_policy && dry_run
    validate_release_version_policy!(
      gem_root: release_root,
      target_gem_version: resolved_target_gem_version,
      allow_override: allow_version_policy_override,
      fetch_tags: should_fetch_tags_for_policy
    )
    if requested_gem_version.empty?
      puts "Computed next patch version: #{resolved_target_gem_version}"
      if dry_run
        puts "DRY RUN: Skipping confirmation prompt for patch release #{resolved_target_gem_version}."
      else
        confirm_or_abort!("Proceed with patch release #{resolved_target_gem_version}?")
      end
    end

    bump_command = if requested_gem_version.empty?
      "gem bump --no-commit"
    else
      "gem bump --no-commit --version #{Shellwords.escape(requested_gem_version)}"
    end
    Shakapacker::Utils::Misc.sh_in_dir(release_root, bump_command)
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "bundle install")

    # Update spec/dummy lockfiles BEFORE release-it so they are included in the release commit.
    # spec/dummy is Yarn-managed, but we also commit package-lock.json for npm compatibility/testing.
    spec_dummy_dir = File.join(release_root, "spec", "dummy")
    Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "bundle install")
    Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "yarn install")
    Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "npm install")

    # Explicitly stage all release-related changes so release-it includes them in its commit.
    # release-it only reliably stages files it modifies (package.json); other working tree
    # changes (version.rb, Gemfile.lock, spec/dummy lockfiles) must be pre-staged.
    staged_files_command = "git add #{Shellwords.join(staged_files)}"
    Shakapacker::Utils::Misc.sh_in_dir(release_root, staged_files_command)

    resolved_gem_version = current_gem_version(release_root)
    released_gem_version = resolved_gem_version
    npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(resolved_gem_version)
    released_npm_version = npm_version
    unless resolved_gem_version == resolved_target_gem_version
      abort "❌ Expected gem bump to produce #{resolved_target_gem_version}, but found #{resolved_gem_version}."
    end

    # Use npx so maintainers don't need a globally installed `release-it` binary.
    # This avoids failures from shim managers (e.g. mise) when `release-it` isn't configured.
    release_it_command = +"npx --yes release-it #{Shellwords.escape(npm_version)}"
    release_it_command << " --npm.publish --no-git.requireCleanWorkingDir"
    release_it_command << " --dry-run --verbose" if dry_run
    npm_dist_tag = npm_dist_tag_for_version(npm_version)
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "NPM target: shakapacker@#{npm_version} (dist-tag: #{npm_dist_tag})"
    puts "Use the OTP for NPM!"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(release_root, release_it_command)

    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Use the OTP for RubyGems!"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "gem release") unless dry_run

  end

  unless dry_run
    sync_gem_version = released_gem_version || gem_version.to_s.strip
    if sync_gem_version && !sync_gem_version.empty?
      released_npm_version ||= Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(sync_gem_version)
      changelog_path = File.join(gem_root, "CHANGELOG.md")
      changelog_section_found = !extract_changelog_section(changelog_path: changelog_path, npm_version: released_npm_version).nil?
      sync_github_release_after_publish(gem_root: gem_root, gem_version: sync_gem_version, dry_run: dry_run)
    end
  end

  {
    dry_run: dry_run,
    released_gem_version: released_gem_version,
    released_npm_version: released_npm_version,
    changelog_section_found: changelog_section_found,
    staged_files: staged_files
  }
end

desc("Releases both the gem and node package using the given version.

Handles both stable and prerelease versions. For prereleases, run
/update-changelog rc (or beta) first to stamp the version in CHANGELOG.md,
then run this task with no arguments to pick it up automatically.

IMPORTANT: the gem version must be in valid rubygem format (no dashes).
It will be automatically converted to npm semver by the rake task.

After publishing, automatically creates a GitHub release from CHANGELOG.md
if a matching section exists. If no section is found, prints a reminder
to update CHANGELOG.md and run sync_github_release manually.

Arguments:
1st argument: The new version in rubygem format (example: 9.6.0 or 9.6.0.rc.0).
              Pass no argument to use the latest version from CHANGELOG.md,
              or fall back to a patch bump if CHANGELOG.md has no new version.
2nd argument: Perform a dry run by passing 'true' as second argument.
3rd argument: Override release version policy checks by passing 'true'.
              Equivalent to setting RELEASE_VERSION_POLICY_OVERRIDE=true.

Examples:
- rake \"release\"                      # uses CHANGELOG.md version or patch bump
- rake \"release[9.6.0]\"
- rake \"release[9.6.0.rc.0]\"
- rake \"release[9.6.0,true]\"
- rake \"release[9.6.0,false,true]\"
")
task :release, %i[gem_version dry_run override_version_policy] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])
  allow_override = version_policy_override_enabled?(args_hash[:override_version_policy])

  requested_version = args_hash[:gem_version].to_s.strip
  if requested_version.empty?
    gem_root = File.expand_path("..", __dir__)
    changelog_version = extract_latest_changelog_version(gem_root: gem_root)
    current_version = current_gem_version(gem_root)

    if changelog_version && Gem::Version.new(changelog_version) > Gem::Version.new(current_version)
      puts "Found CHANGELOG.md version: #{changelog_version} (current: #{current_version})"
      if is_dry_run
        puts "DRY RUN: Skipping confirmation prompt for CHANGELOG.md version #{changelog_version}."
      else
        confirm_or_abort!("Release #{changelog_version} from CHANGELOG.md?")
      end
      requested_version = changelog_version
    else
      puts "No new version found in CHANGELOG.md (latest: #{changelog_version || 'none'}, current: #{current_version})."
      puts "Falling back to patch bump."
    end
  end

  release_result = perform_release(
    gem_version: requested_version,
    dry_run: is_dry_run,
    allow_version_policy_override: allow_override
  )
  print_release_summary(release_result)
end

desc("Creates or updates a GitHub release from CHANGELOG.md for an already-published gem version.

IMPORTANT: pass gem version in RubyGems format (e.g. 9.6.0.rc.1), and ensure matching changelog
header exists in npm format (e.g. ## [v9.6.0-rc.1]).

Arguments:
1st argument: Gem version in RubyGems format (required).
2nd argument: Perform a dry run by passing 'true'.

Examples:
- rake \"sync_github_release[9.6.0]\"
- rake \"sync_github_release[9.6.0.rc.1]\"
- rake \"sync_github_release[9.6.0.rc.1,true]\"
")
task :sync_github_release, %i[gem_version dry_run] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])

  requested_gem_version = args_hash[:gem_version].to_s.strip
  if requested_gem_version.empty?
    abort "❌ gem_version is required. Usage: rake \"sync_github_release[9.6.0]\" or rake \"sync_github_release[9.6.0.rc.1]\""
  end
  validate_requested_gem_version!(requested_gem_version)

  gem_root = File.expand_path("..", __dir__)
  puts "ℹ️ sync_github_release reads local committed CHANGELOG.md; run `git pull --rebase` first if you want the latest remote notes."
  if is_dry_run
    if changelog_dirty?(gem_root: gem_root)
      abort "❌ DRY RUN: CHANGELOG.md has uncommitted changes. Commit or stash CHANGELOG.md before running sync_github_release."
    end
    puts "DRY RUN: Validating CHANGELOG.md section exists for the requested version..."
  else
    ensure_changelog_committed!(gem_root: gem_root)
  end

  verify_gh_auth(gem_root: gem_root)
  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(requested_gem_version)
  release_context = prepare_github_release_context(
    gem_root: gem_root,
    npm_version: npm_version,
    gem_version: requested_gem_version
  )
  publish_or_update_github_release(gem_root: gem_root, release_context: release_context, dry_run: is_dry_run)
end
