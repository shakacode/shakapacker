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
  escaped_registry_url = Shellwords.escape(registry_url)
  result = `npm whoami --registry #{escaped_registry_url} 2>&1`
  unless $CHILD_STATUS.success?
    puts "⚠️  NPM authentication required!"
    puts "Please run: npm login --registry #{display_registry_url}"
    puts ""
    system("npm login --registry #{escaped_registry_url}")
    result = `npm whoami --registry #{escaped_registry_url} 2>&1`
    unless $CHILD_STATUS.success?
      abort "❌ NPM login failed! Please authenticate with npm before running the release."
    end
  end
  puts "✓ Logged in to NPM as: #{result.strip}"
end

def verify_gh_auth(gem_root:)
  result, status = Open3.capture2e("gh", "auth", "status")
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

def tagged_release_gem_versions(gem_root)
  fetch_output, fetch_status = Open3.capture2e("git", "-C", gem_root, "fetch", "--tags", "--quiet")
  abort "❌ Unable to fetch tags for version policy validation.\n\n#{fetch_output.strip}" unless fetch_status.success?

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
  downcased_section = section.downcase
  return :major if downcased_section.match?(/\bbreaking\b/) || section.match?(/^###\s+.*breaking/i)
  return :minor if section.match?(/^###\s+Added\b/i)
  return :patch if section.match?(/^###\s+(Fixed|Security|Changed|Improved|Documentation)\b/i)

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

def validate_release_version_policy!(gem_root:, target_gem_version:, allow_override:)
  tagged_versions = tagged_release_gem_versions(gem_root)
  latest_tagged_version = tagged_versions.max_by { |version| Gem::Version.new(version) }

  if latest_tagged_version && Gem::Version.new(target_gem_version) <= Gem::Version.new(latest_tagged_version)
    handle_version_policy_violation!(
      message: "❌ Requested version #{target_gem_version} must be greater than latest tagged version #{latest_tagged_version}.",
      allow_override: allow_override
    )
  end

  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(target_gem_version)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  changelog_section = extract_changelog_section(changelog_path: changelog_path, npm_version: npm_version)
  changelog_source = "v#{npm_version}"
  unless changelog_section
    changelog_section = extract_unreleased_changelog_section(changelog_path: changelog_path)
    changelog_source = "Unreleased" if changelog_section
  end

  if prerelease_gem_version?(target_gem_version) && latest_tagged_version
    target_components = parse_gem_version_components(target_gem_version)
    latest_components = parse_gem_version_components(latest_tagged_version)
    same_release_base = target_components[:major] == latest_components[:major] &&
      target_components[:minor] == latest_components[:minor] &&
      target_components[:patch] == latest_components[:patch]
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
    return
  end

  unless changelog_section
    puts "ℹ️ VERSION POLICY: No changelog content found for v#{npm_version} or [Unreleased]; skipping changelog bump-consistency check."
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

def extract_changelog_section(changelog_path:, npm_version:)
  lines = File.readlines(changelog_path)
  section_header = /^## \[v#{Regexp.escape(npm_version)}\]/
  start_index = lines.index { |line| line.match?(section_header) }
  return nil unless start_index

  end_index = ((start_index + 1)...lines.length).find { |idx| lines[idx].start_with?("## [") } || lines.length
  lines[start_index...end_index].join.rstrip
end

def extract_unreleased_changelog_section(changelog_path:)
  lines = File.readlines(changelog_path)
  start_index = lines.index { |line| line.match?(/^## \[Unreleased\]/i) }
  return nil unless start_index

  end_index = ((start_index + 1)...lines.length).find { |idx| lines[idx].start_with?("## [") } || lines.length
  lines[start_index...end_index].join.rstrip
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
  abort "❌ Unable to check CHANGELOG.md status" unless status.success?
  !changes_output.strip.empty?
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

def publish_or_update_github_release(gem_root:, release_context:, dry_run:)
  if dry_run
    puts "DRY RUN: Would create or update GitHub release #{release_context[:tag]}#{release_context[:prerelease] ? ' (prerelease)' : ''}"
    return
  end

  ensure_git_tag_exists!(gem_root: gem_root, tag: release_context[:tag])

  Tempfile.create(["shakapacker-release-notes-", ".md"]) do |tmp|
    tmp.write(release_context[:notes])
    tmp.flush

    # The view probe only needs a boolean result, so use array-form system to avoid an extra shell layer.
    release_exists = system("gh", "release", "view", release_context[:tag], chdir: gem_root, out: File::NULL, err: File::NULL)

    release_command = if release_exists
      # `gh release edit` accepts `--prerelease=true|false`; there is no `--no-prerelease` flag.
      ["gh", "release", "edit", release_context[:tag], "--title", release_context[:title], "--notes-file", tmp.path,
       "--prerelease=#{release_context[:prerelease]}"]
    else
      command = ["gh", "release", "create", release_context[:tag], "--verify-tag", "--title", release_context[:title],
                 "--notes-file", tmp.path]
      command << "--prerelease" if release_context[:prerelease]
      command
    end

    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Publishing GitHub release #{release_context[:tag]}#{release_context[:prerelease] ? ' (prerelease)' : ''}"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
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

def next_prerelease_gem_version(gem_root:, base_version:, prerelease_type:)
  normalized_type = prerelease_type.to_s.strip
  unless %w[beta rc].include?(normalized_type)
    abort "❌ prerelease_type must be one of: beta, rc"
  end

  unless base_version.match?(/\A\d+\.\d+\.\d+\z/)
    abort "❌ base_version must be in major.minor.patch format, for example 9.6.0"
  end

  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git fetch --tags --quiet")
  # Git tags use npm semver format (dashes) because release-it creates the tag from the npm version.
  # e.g., v9.6.0-rc.0, not v9.6.0.rc.0
  tag_pattern = "v#{base_version}-#{normalized_type}.*"
  existing_tags = `git -C #{Shellwords.escape(gem_root)} tag -l #{Shellwords.escape(tag_pattern)}`
  abort "❌ Unable to list existing tags for prerelease calculation" unless $CHILD_STATUS.success?

  tag_regex = /\Av#{Regexp.escape(base_version)}-#{Regexp.escape(normalized_type)}\.(\d+)\z/
  max_existing_index = existing_tags.lines.map(&:strip).filter_map { |tag| tag.match(tag_regex)&.captures&.first&.to_i }.max
  next_index = max_existing_index.nil? ? 0 : max_existing_index + 1

  "#{base_version}.#{normalized_type}.#{next_index}"
end

def confirm_or_abort!(prompt)
  return if Shakapacker::Utils::Misc.object_to_boolean(ENV["AUTO_CONFIRM"])

  print "#{prompt} [y/N]: "
  answer = $stdin.gets.to_s.strip.downcase
  abort "❌ Aborted by user." unless %w[y yes].include?(answer)
end

def perform_release(gem_version:, dry_run:, check_uncommitted: true, allow_version_policy_override: false)
  ensure_clean_worktree! if check_uncommitted
  gem_root = File.expand_path("..", __dir__)
  # This is filled inside the release checkout block and used for the post-release sync reminder.
  released_gem_version = nil

  unless dry_run
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "PRE-FLIGHT CHECKS"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    verify_npm_auth
  end

  requested_gem_version = gem_version.to_s.strip
  validate_requested_gem_version!(requested_gem_version)

  with_release_checkout(gem_root: gem_root, dry_run: dry_run) do |release_root|
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "git pull --rebase") unless dry_run

    # The release root may change after `git pull --rebase`, so patch-bump inference must happen after that step.
    resolved_target_gem_version = target_gem_version(gem_root: release_root, requested_gem_version: requested_gem_version)
    validate_release_version_policy!(
      gem_root: release_root,
      target_gem_version: resolved_target_gem_version,
      allow_override: allow_version_policy_override
    )

    bump_command = if requested_gem_version.empty?
      "gem bump --no-commit"
    else
      "gem bump --no-commit --version #{Shellwords.escape(requested_gem_version)}"
    end
    Shakapacker::Utils::Misc.sh_in_dir(release_root, bump_command)
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "bundle install")

    resolved_gem_version = current_gem_version(release_root)
    released_gem_version = resolved_gem_version
    npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(resolved_gem_version)
    unless resolved_gem_version == resolved_target_gem_version
      abort "❌ Expected gem bump to produce #{resolved_target_gem_version}, but found #{resolved_gem_version}."
    end

    release_it_command = +"release-it #{Shellwords.escape(npm_version)}"
    release_it_command << " --npm.publish --no-git.requireCleanWorkingDir"
    release_it_command << " --dry-run --verbose" if dry_run
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Use the OTP for NPM!"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(release_root, release_it_command)

    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Use the OTP for RubyGems!"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "gem release") unless dry_run

    spec_dummy_dir = File.join(release_root, "spec", "dummy")
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Updating spec/dummy dependencies"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "bundle install") unless dry_run
    Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "npm install") unless dry_run

    lockfiles = ["spec/dummy/Gemfile.lock", "spec/dummy/package-lock.json", "spec/dummy/yarn.lock"]
    existing_lockfiles = lockfiles.select { |f| File.exist?(File.join(release_root, f)) }
    changed_lockfiles = existing_lockfiles.select do |lockfile|
      changes_output = `git -C #{Shellwords.escape(release_root)} status --porcelain -- #{Shellwords.escape(lockfile)}`
      !changes_output.strip.empty?
    end

    if !changed_lockfiles.empty? && !dry_run
      puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
      puts "Committing and pushing spec/dummy lockfile changes: #{changed_lockfiles.join(', ')}"
      puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
      escaped_lockfiles = changed_lockfiles.map { |path| Shellwords.escape(path) }.join(" ")
      Shakapacker::Utils::Misc.sh_in_dir(release_root, "git add -- #{escaped_lockfiles}")
      Shakapacker::Utils::Misc.sh_in_dir(release_root, "git commit -m 'Update spec/dummy lockfiles after release'")
      Shakapacker::Utils::Misc.sh_in_dir(release_root, "git push")
    end

  end

  unless dry_run
    sync_gem_version = released_gem_version || gem_version.to_s.strip
    sync_gem_version = "<released_gem_version>" if sync_gem_version.empty?
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Reminder: after updating and committing CHANGELOG.md, run:"
    puts "bundle exec rake \"sync_github_release[#{sync_gem_version}]\""
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  end
end

desc("Releases both the gem and node package using the given version.

IMPORTANT: the gem version must be in valid rubygem format (no dashes).
It will be automatically converted to npm semver by the rake task.

GitHub release sync is a separate step via `sync_github_release`.

Arguments:
1st argument: The new version in rubygem format (example: 9.6.0.rc.0).
              Pass no argument to perform a patch bump.
2nd argument: Perform a dry run by passing 'true' as second argument.
3rd argument: Override release version policy checks by passing 'true'.
              Equivalent to setting RELEASE_VERSION_POLICY_OVERRIDE=true.

Examples:
- rake \"create_release[9.6.0]\"
- rake \"create_release[9.6.0.rc.0]\"
- rake \"create_release[9.6.0,true]\"
- rake \"create_release[9.6.0,false,true]\"
")
task :create_release, %i[gem_version dry_run override_version_policy] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])
  allow_override = version_policy_override_enabled?(args_hash[:override_version_policy])
  perform_release(gem_version: args_hash[:gem_version], dry_run: is_dry_run, allow_version_policy_override: allow_override)
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
  puts "ℹ️ sync_github_release reads local committed CHANGELOG.md; run `git pull --rebase` first if you want the latest remote notes." unless is_dry_run
  if is_dry_run
    if changelog_dirty?(gem_root: gem_root)
      abort "⚠️ DRY RUN: CHANGELOG.md has uncommitted changes. Commit or stash CHANGELOG.md before running sync_github_release."
    end
    puts "DRY RUN: Validating CHANGELOG.md section exists for the requested version..."
  else
    ensure_changelog_committed!(gem_root: gem_root)
  end

  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(requested_gem_version)
  release_context = prepare_github_release_context(
    gem_root: gem_root,
    npm_version: npm_version,
    gem_version: requested_gem_version
  )
  verify_gh_auth(gem_root: gem_root) unless is_dry_run
  publish_or_update_github_release(gem_root: gem_root, release_context: release_context, dry_run: is_dry_run)
end

desc("Creates the next prerelease automatically and then runs create_release.

Examples:
- rake \"create_prerelease[9.6.0]\"          # defaults to rc -> 9.6.0.rc.0 or next rc index
- rake \"create_prerelease[9.6.0,rc]\"       # -> 9.6.0.rc.0 or next rc index
- rake \"create_prerelease[9.6.0,beta]\"     # -> 9.6.0.beta.0 or next beta index
- rake \"create_prerelease[9.6.0,rc,true]\"  # dry run

Notes:
- If prerelease_type is omitted, it defaults to 'rc'.
- Prompts for confirmation before continuing (set AUTO_CONFIRM=true to skip).
- Uses git tags to compute the next prerelease index.
- Release version policy checks can be overridden via 4th arg 'true' or RELEASE_VERSION_POLICY_OVERRIDE=true.
")
task :create_prerelease, %i[base_version prerelease_type dry_run override_version_policy] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])
  allow_override = version_policy_override_enabled?(args_hash[:override_version_policy])
  gem_root = File.expand_path("..", __dir__)
  ensure_clean_worktree!

  base_version = args_hash[:base_version].to_s.strip
  if base_version.empty?
    abort "❌ base_version is required. Usage: rake \"create_prerelease[9.6.0]\" or rake \"create_prerelease[9.6.0,beta]\""
  end

  prerelease_type = args_hash[:prerelease_type].to_s.strip
  if prerelease_type.empty?
    prerelease_type = "rc"
    puts "No prerelease_type provided, defaulting to rc."
  end
  next_version = next_prerelease_gem_version(
    gem_root: gem_root,
    base_version: base_version,
    prerelease_type: prerelease_type
  )

  puts "Computed next prerelease version: #{next_version}"
  confirm_or_abort!("Proceed with prerelease #{next_version}?") unless is_dry_run

  perform_release(
    gem_version: next_version,
    dry_run: is_dry_run,
    check_uncommitted: false,
    allow_version_policy_override: allow_override
  )
end
