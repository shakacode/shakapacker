require_relative File.join("..", "lib", "shakapacker", "utils", "version_syntax_converter")
require_relative File.join("..", "lib", "shakapacker", "utils", "misc")
require "English"
require "bundler"
require "rubygems/version"
require "shellwords"
require "open3"
require "tempfile"
require "tmpdir"
require "json"
require "securerandom"

GITHUB_REPO_SLUG_PATTERN = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/ unless defined?(GITHUB_REPO_SLUG_PATTERN)

# A release-gating result only counts as green when it finished successfully.
CI_PASSING_CONCLUSIONS = %w[success].freeze unless defined?(CI_PASSING_CONCLUSIONS)
REQUIRED_MAIN_PUSH_WORKFLOWS = [
  "Dummy specs",
  "Generator specs",
  "Node based checks",
  "Ruby based checks",
  "Test Both Bundlers"
].freeze unless defined?(REQUIRED_MAIN_PUSH_WORKFLOWS)
CONDITIONAL_MAIN_PUSH_WORKFLOWS = ["Babel 8 smoke"].freeze unless defined?(CONDITIONAL_MAIN_PUSH_WORKFLOWS)

# `prepublishOnly` (`yarn build && yarn type-check`) resolves these from node_modules/.bin.
REQUIRED_RELEASE_NODE_BINARIES = %w[prettier tsc].freeze unless defined?(REQUIRED_RELEASE_NODE_BINARIES)

unless defined?(AbortingMessageHandler)
  class AbortingMessageHandler
    def add_error(error)
      abort "❌ #{error}"
    end
  end
end

def ensure_clean_worktree!
  Shakapacker::Utils::Misc.uncommitted_changes?(AbortingMessageHandler.new)
end

def github_repo_slug(gem_root)
  origin_url, status = Open3.capture2e("git", "-C", gem_root, "remote", "get-url", "origin")
  origin_url = origin_url.strip
  abort "❌ Unable to determine git origin URL for GitHub release checks.\n\n#{origin_url}" unless status.success?

  match = origin_url.match(%r{\Agit@github\.com:(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
    origin_url.match(%r{\Assh://git@github\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
    origin_url.match(%r{\Ahttps://(?:[^/@]+@)?github\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
    origin_url.match(%r{\Agit://github\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z}) ||
    # Keep bare github.com/owner/repo support for remotes copied without a scheme.
    origin_url.match(%r{\Agithub\.com/(?<repo>[^/]+/[^/]+?)(?:\.git)?\z})
  abort "❌ Unable to determine GitHub repository from origin URL #{origin_url.inspect}" unless match

  repo_slug = match[:repo]
  unless repo_slug.match?(GITHUB_REPO_SLUG_PATTERN)
    abort "❌ GitHub repository slug #{repo_slug.inspect} from origin URL #{origin_url.inspect} is invalid."
  end

  repo_slug
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

# `npm publish` runs `prepublishOnly`, whose binaries resolve from node_modules/.bin. That
# happens long after the version bump, commit, tag, and push, so a missing local install
# burns a public tag on a release that never reaches a registry — exactly what happened on
# v10.3.2 (`tsc: command not found`). Fail closed here, before anything is mutated.
def verify_node_modules!(gem_root:)
  bin_dir = File.join(gem_root, "node_modules", ".bin")
  unless File.directory?(bin_dir)
    abort "❌ Node dependencies are not installed (#{bin_dir} is missing). Run `yarn install` and retry."
  end

  missing = REQUIRED_RELEASE_NODE_BINARIES.reject { |binary| File.executable?(File.join(bin_dir, binary)) }
  unless missing.empty?
    abort "❌ Node dependencies are incomplete: #{missing.join(', ')} missing from #{bin_dir}. " \
          "`npm publish` runs prepublishOnly (`yarn build && yarn type-check`), which needs them. " \
          "Run `yarn install` and retry."
  end

  verify_node_modules_match_manifest!(gem_root: gem_root)

  puts "✓ Node dependencies installed and matching package.json"
end

# Binary presence alone does not prove a usable install. `prepublishOnly` compiles the whole
# package, resolving far more than tsc and prettier, and two realistic states leave those two
# on disk while that deeper resolution still fails: an install interrupted partway, and a
# release run right after merging dependency changes, where node_modules predates package.json.
#
# Yarn writes node_modules/.yarn-integrity only once an install finishes, recording the exact
# `name@spec` patterns package.json declared at that moment. Comparing the manifest against
# yarn's own marker catches both states without running a build or touching the working tree.
def verify_node_modules_match_manifest!(gem_root:)
  integrity_path = File.join(gem_root, "node_modules", ".yarn-integrity")
  unless File.exist?(integrity_path)
    abort "❌ Node dependencies are incompletely installed (#{integrity_path} is missing, so no " \
          "`yarn install` ever finished). Run `yarn install` and retry."
  end

  manifest_path = File.join(gem_root, "package.json")
  package_json = begin
    JSON.parse(File.read(manifest_path))
  rescue JSON::ParserError, SystemCallError => e
    # Unlike the marker, package.json is the manifest being released. A broken one cannot be
    # skipped past, so it aborts with an actionable message rather than a raw backtrace.
    abort "❌ Unable to read #{manifest_path} for the node dependency check: #{e.message}"
  end
  # `[]`, `"x"`, `42`, `true` and `null` are all valid JSON, so parsing succeeding does not mean
  # the manifest is an object. Indexing those raises TypeError or NoMethodError — and a String
  # root is worse still, since `"x"["dependencies"]` returns nil, so every section would read as
  # empty and the whole check would pass vacuously on a nonsense manifest.
  unless package_json.is_a?(Hash)
    abort "❌ #{manifest_path} is not a JSON object (got #{package_json.class}). " \
          "Fix package.json and retry."
  end

  # Runs before the marker is even parsed: it needs only package.json, so an unreadable marker
  # must not silently skip it too.
  verify_declared_packages_present!(gem_root: gem_root, package_json: package_json, manifest_path: manifest_path)

  recorded_patterns = begin
    JSON.parse(File.read(integrity_path))["topLevelPatterns"]
  rescue JSON::ParserError, SystemCallError
    nil
  end
  # An unreadable or differently-shaped marker means a yarn version whose format this cannot
  # compare. Skip drift detection rather than block a release on an unverifiable signal.
  return unless recorded_patterns.is_a?(Array)

  declared_patterns = %w[dependencies devDependencies optionalDependencies].flat_map do |key|
    declared_dependency_section(package_json: package_json, manifest_path: manifest_path, key: key)
      .map { |name, spec| "#{name}@#{spec}" }
  end

  # One-directional on purpose: leftover entries in the marker are harmless, while a pattern
  # package.json declares and the install never saw is exactly the stale-install case.
  stale = declared_patterns - recorded_patterns
  return if stale.empty?

  abort "❌ Node dependencies are stale: package.json declares #{stale.join(', ')}, which the " \
        "installed node_modules does not have. Run `yarn install` and retry."
end

# The integrity marker records what a completed install *requested*, not what survived it. A
# package removed afterwards — or lost to an install interrupted after an earlier successful one,
# which leaves the previous marker in place — keeps the marker consistent while the build input
# is gone. So check the tree itself, not just yarn's record of it.
#
# Optional dependencies are excluded: they are permitted to be absent by definition.
def verify_declared_packages_present!(gem_root:, package_json:, manifest_path:)
  node_modules_dir = File.join(gem_root, "node_modules")
  required_names = %w[dependencies devDependencies].flat_map do |key|
    declared_dependency_section(package_json: package_json, manifest_path: manifest_path, key: key).keys
  end
  # npm treats an optionalDependencies entry as overriding a dependencies entry of the same name,
  # so a package listed in both may be legitimately absent after a successful install. Without
  # this subtraction the exclusion above silently fails for exactly that case, and the release
  # would abort every time — even immediately after the `yarn install` the message prescribes.
  required_names -= declared_dependency_section(
    package_json: package_json, manifest_path: manifest_path, key: "optionalDependencies"
  ).keys

  # A package declared in both dependencies and devDependencies appears twice, which would
  # otherwise repeat the name in the abort message.
  absent = required_names.uniq.reject { |name| File.directory?(File.join(node_modules_dir, name)) }
  return if absent.empty?

  abort "❌ Node dependencies are damaged: #{absent.join(', ')} declared in package.json but " \
        "missing from #{node_modules_dir}. Run `yarn install` and retry."
end

# package.json is the manifest being released, so a malformed dependency section must abort with an
# actionable message rather than escape as a NoMethodError backtrace from `.keys` / `.map`. An
# Array is the quieter case: it survives `.map` and yields garbage patterns the drift comparison
# would otherwise trust.
def declared_dependency_section(package_json:, manifest_path:, key:)
  section = package_json[key]
  return {} if section.nil?
  return section if section.is_a?(Hash)

  abort "❌ #{manifest_path} has a malformed #{key} section: expected an object mapping package " \
        "names to version specs, got #{section.class}. Fix package.json and retry."
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

def resolve_implicit_release_version(gem_root:, dry_run:)
  changelog_version = extract_latest_changelog_version(gem_root: gem_root)
  current_version = current_gem_version(gem_root)

  if changelog_version && Gem::Version.new(changelog_version) > Gem::Version.new(current_version)
    puts "Found CHANGELOG.md version: #{changelog_version} (current: #{current_version})"
    if dry_run
      puts "DRY RUN: Skipping confirmation prompt for CHANGELOG.md version #{changelog_version}."
    else
      confirm_or_abort!("Release #{changelog_version} from CHANGELOG.md?")
    end
    return changelog_version
  end

  puts "No new version found in CHANGELOG.md (latest: #{changelog_version || 'none'}, current: #{current_version})."
  puts "Falling back to patch bump."
  ""
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

def ci_status_override_enabled?(override_flag)
  Shakapacker::Utils::Misc.object_to_boolean(override_flag) ||
    Shakapacker::Utils::Misc.object_to_boolean(ENV["RELEASE_CI_STATUS_OVERRIDE"])
end

def handle_ci_status_violation!(message:, allow_override:, dry_run:)
  normalized = message.sub(/\A❌\s*/, "")

  if allow_override
    puts "⚠️ CI STATUS OVERRIDE enabled: #{normalized}"
  elsif dry_run
    puts "DRY RUN: Release would be blocked: #{normalized}"
  else
    abort message
  end
end

def release_head_sha(gem_root)
  output, status = Open3.capture2e("git", "-C", gem_root, "rev-parse", "HEAD")
  output = output.strip
  abort "❌ Unable to determine HEAD commit for CI status validation.\n\n#{output}" unless status.success?

  output
end

# `gh api --paginate --jq` flattens paginated responses into JSONL, one object per line.
# Returns [rows, error_message]; the error is surfaced through the violation handler so a
# missing `gh` or an API failure blocks a live release but only reports during a dry run.
def fetch_gh_jsonl(api_path, jq_filter)
  begin
    output, error_output, status = Open3.capture3("gh", "api", "--paginate", "--jq", jq_filter, api_path)
  rescue Errno::ENOENT
    return [nil, "GitHub CLI is not installed or not available on PATH. Install `gh` and retry."]
  end
  unless status.success?
    diagnostics = [error_output, output].map(&:strip).reject(&:empty?).join("\n")
    return [nil, diagnostics]
  end

  rows = output.lines.reject { |line| line.strip.empty? }.map { |line| JSON.parse(line) }
  [rows, nil]
rescue JSON::ParserError => e
  [nil, "Failed to parse response from gh: #{e.message}"]
end

def fetch_main_push_workflow_runs(repo_slug:, commit_sha:)
  rows, error = fetch_gh_jsonl(
    "repos/#{repo_slug}/actions/runs?head_sha=#{commit_sha}&event=push&branch=main&per_page=100",
    ".workflow_runs[]"
  )
  return [nil, error] if error

  normalized_runs = rows.map do |run|
    {
      id: run["id"].to_i,
      name: run["name"].to_s,
      status: run["status"].to_s,
      conclusion: run["conclusion"].to_s
    }
  end

  # A workflow can be dispatched again for the same commit. Older failed or cancelled
  # rows must not override the newest result for that workflow.
  latest_runs = normalized_runs.group_by { |run| run[:name] }.values.map do |runs|
    runs.max_by { |run| run[:id] }
  end
  [latest_runs, nil]
end

# Not every integration reports through GitHub Actions. CodeRabbit, for one, posts legacy
# commit statuses, so those remain supplemental fail-closed signals. The combined-status
# endpoint returns only the latest status per context.
def fetch_commit_statuses(repo_slug:, commit_sha:)
  rows, error = fetch_gh_jsonl("repos/#{repo_slug}/commits/#{commit_sha}/status", ".statuses[]")
  return [nil, error] if error

  [rows.map { |status| normalize_status_as_check_run(status) }, nil]
end

def normalize_status_as_check_run(status)
  conclusion = normalize_status_conclusion(status["state"])

  {
    name: status["context"].to_s,
    # A nil conclusion means the status is still pending, which must block like an
    # in-progress check run rather than counting as a pass.
    status: conclusion.nil? ? "pending" : "completed",
    conclusion: conclusion.to_s
  }
end

def normalize_status_conclusion(state)
  case state
  when "success" then "success"
  when "pending" then nil
  when "failure", "error" then state
  else
    # GitHub documents error/failure/pending/success; anything else is unknown, so block.
    "error"
  end
end

def classify_check_runs(check_runs, passing_conclusions: CI_PASSING_CONCLUSIONS)
  pending, failing = check_runs.partition { |run| run[:status] != "completed" }
  failing = failing.reject { |run| passing_conclusions.include?(run[:conclusion]) }

  { pending: pending, failing: failing }
end

def format_check_run_problems(pending:, failing:)
  details = +""

  unless failing.empty?
    details << "\n\nNot passing (#{failing.length}):\n"
    details << failing.map { |run| "  - #{run[:name]} (#{run[:conclusion]})" }.join("\n")
  end

  unless pending.empty?
    details << "\n\nStill running (#{pending.length}):\n"
    details << pending.map { |run| "  - #{run[:name]} (#{run[:status]})" }.join("\n")
  end

  details
end

# Gates the release on CI results for the commit that is about to be released.
# The version-bump commit does not exist yet, so this validates its parent — the
# code being published. Failing closed is deliberate: if CI status cannot be read,
# the release stops rather than assuming green.
def validate_release_ci_status!(gem_root:, allow_override:, dry_run:)
  repo_slug = github_repo_slug(gem_root)
  commit_sha = release_head_sha(gem_root)

  workflow_runs, error = fetch_main_push_workflow_runs(repo_slug: repo_slug, commit_sha: commit_sha)
  statuses, status_error = fetch_commit_statuses(repo_slug: repo_slug, commit_sha: commit_sha) unless error
  error ||= status_error

  if error
    handle_ci_status_violation!(
      message: "❌ Unable to verify CI status for #{commit_sha} on #{repo_slug}.\n\n#{error}",
      allow_override: allow_override,
      dry_run: dry_run
    )
    return
  end

  workflow_names = workflow_runs.map { |run| run[:name] }
  missing_workflows = REQUIRED_MAIN_PUSH_WORKFLOWS - workflow_names
  unless missing_workflows.empty?
    handle_ci_status_violation!(
      message: "❌ Missing main-push workflows for #{commit_sha}: #{missing_workflows.join(', ')}. " \
               "Wait for the complete main CI suite to start before releasing.",
      allow_override: allow_override,
      dry_run: dry_run
    )
    return
  end

  gating_workflow_names = REQUIRED_MAIN_PUSH_WORKFLOWS + CONDITIONAL_MAIN_PUSH_WORKFLOWS
  gating_workflow_runs = workflow_runs.select { |run| gating_workflow_names.include?(run[:name]) }
  workflow_results = classify_check_runs(gating_workflow_runs, passing_conclusions: CI_PASSING_CONCLUSIONS)
  status_results = classify_check_runs(statuses)
  pending = workflow_results[:pending] + status_results[:pending]
  failing = workflow_results[:failing] + status_results[:failing]

  if pending.empty? && failing.empty?
    puts "✓ CI is green for #{commit_sha} (#{gating_workflow_runs.length} main-push workflows, #{statuses.length} commit-status signals)"
    return
  end

  handle_ci_status_violation!(
    message: "❌ CI is not green for #{commit_sha}, the commit that would be released." \
             "#{format_check_run_problems(pending: pending, failing: failing)}\n\n" \
             "Fix CI (or wait for it to finish) and retry. " \
             "To release anyway, set RELEASE_CI_STATUS_OVERRIDE=true.",
    allow_override: allow_override,
    dry_run: dry_run
  )
end

def extract_latest_changelog_version(gem_root:)
  changelog_path = File.join(gem_root, "CHANGELOG.md")
  return nil unless File.exist?(changelog_path)

  converter = Shakapacker::Utils::VersionSyntaxConverter.new
  # CHANGELOG.md holds non-ASCII (em dashes, ⚠️). Without an explicit encoding these lines
  # inherit a non-UTF-8 Encoding.default_external when LANG/LC_ALL are unset, and matching
  # them raises ArgumentError instead of scanning cleanly.
  File.readlines(changelog_path, encoding: "UTF-8").each do |line|
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

def sync_github_release_after_publish(gem_root:, gem_version:, dry_run:, changelog_section: nil)
  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(gem_version)
  section = changelog_section || extract_changelog_section(
    changelog_path: File.join(gem_root, "CHANGELOG.md"), npm_version: npm_version
  )

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
  lines = File.readlines(changelog_path, encoding: "UTF-8")
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
    # release-it runs `git symbolic-ref HEAD`, which fails on a detached HEAD and aborts the
    # dry run, so the worktree gets a throwaway branch that the ensure block deletes.
    #
    # The random suffix is what makes this safe, not the PID: a dry run killed hard enough to
    # skip the ensure block leaves the branch checked out in a registered worktree, and git
    # then refuses to reuse that name ("is already used by worktree at ...") — including under
    # `-B`, which only creates-or-resets a branch and cannot claim one held by another
    # worktree. A fresh name per run can never collide with that leftover.
    dry_run_branch = "release-dry-run-#{Process.pid}-#{SecureRandom.hex(4)}"
    escaped_dry_run_branch = Shellwords.escape(dry_run_branch)

    # Drop registrations whose directories are already gone, so leaked worktrees from
    # hard-killed runs do not accumulate in the maintainer's checkout.
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git worktree prune")

    # Dry runs should exercise the release flow without dirtying the maintainer's checkout.
    Shakapacker::Utils::Misc.sh_in_dir(
      gem_root,
      "git worktree add -b #{escaped_dry_run_branch} #{escaped_worktree_dir} HEAD"
    )
    begin
      # Match the live `git pull --rebase` result without changing the maintainer's checkout.
      fetch_output, fetch_status = Open3.capture2e("git", "-C", worktree_dir, "fetch", "origin", "main")
      unless fetch_status.success?
        abort "❌ Unable to fetch origin/main for the dry run. Check network access and the origin remote.\n\n#{fetch_output.strip}"
      end

      rebase_output, rebase_status = Open3.capture2e("git", "-C", worktree_dir, "rebase", "origin/main")
      unless rebase_status.success?
        abort "❌ Unable to rebase the dry run onto origin/main. Update or reconcile the branch, then retry.\n\n#{rebase_output.strip}"
      end

      # release-it also refuses to run without an upstream for the current branch, and the
      # throwaway branch has none until it tracks the branch the dry run just rebased onto.
      upstream_output, upstream_status = Open3.capture2e(
        "git", "-C", worktree_dir, "branch", "--set-upstream-to=origin/main", dry_run_branch
      )
      unless upstream_status.success?
        abort "❌ Unable to track origin/main from the dry-run branch. Check that origin/main exists locally.\n\n#{upstream_output.strip}"
      end
      yield(worktree_dir)
    ensure
      original_error = $ERROR_INFO
      cleanup_errors = []

      # `sh_in_dir` raises on a non-zero exit, so these must be attempted independently:
      # chaining them would let a failed `worktree remove` skip the branch deletion and leak
      # exactly the branch this cleanup exists to remove.
      [
        "git worktree remove --force #{escaped_worktree_dir}",
        "git branch -D #{escaped_dry_run_branch}"
      ].each do |cleanup_command|
        Shakapacker::Utils::Misc.sh_in_dir(gem_root, cleanup_command)
      rescue Exception => cleanup_error # rubocop:disable Lint/RescueException
        # Preserve any release failure already propagating, even if cleanup exits outside StandardError.
        warn "⚠️ Failed to clean up dry-run release worktree #{worktree_dir} " \
             "(#{cleanup_command}): #{cleanup_error.message}"
        cleanup_errors << cleanup_error
      end

      raise cleanup_errors.first if cleanup_errors.any? && !original_error
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

def supplemental_package_dirs
  [
    "packages/shakapacker-webpack",
    "packages/shakapacker-rspack"
  ]
end

# Rewrites `dependencies.shakapacker` in a supplemental package.json to
# `~<npm_version>` while preserving JSON formatting (2-space indent,
# trailing newline) so the diff stays minimal.
def bump_supplemental_core_dep(full_pkg_dir, npm_version)
  pkg_json_path = File.join(full_pkg_dir, "package.json")
  pkg_json = JSON.parse(File.read(pkg_json_path))
  unless pkg_json.dig("dependencies", "shakapacker")
    abort "❌ Expected dependencies.shakapacker in #{pkg_json_path} but found none."
  end
  pkg_json["dependencies"]["shakapacker"] = "~#{npm_version}"
  File.write(pkg_json_path, "#{JSON.pretty_generate(pkg_json)}\n")
end

# spec/dummy is Yarn-managed, but package-lock.json is committed too for npm
# compatibility/testing.
#
# The bundle install must run with the parent Bundler environment removed.
# `bundle exec rake release` exports BUNDLE_GEMFILE pointing at the gem root, and a plain
# `cd spec/dummy && bundle install` inherits it — so it re-resolves the ROOT Gemfile and
# leaves spec/dummy/Gemfile.lock pinned to the pre-bump version. That drift then breaks CI
# on the release commit, where spec/dummy installs in frozen mode. The Rakefile spec tasks
# unbundle for the same reason.
def refresh_spec_dummy_lockfiles(release_root)
  spec_dummy_dir = File.join(release_root, "spec", "dummy")

  Bundler.with_unbundled_env do
    Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "bundle install")
  end
  Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "yarn install")
  Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "npm install")
end

def refresh_release_root_lockfile(release_root)
  Bundler.with_unbundled_env do
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "bundle install")
  end
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
    supplemental_package_dirs.each { |dir| puts "  - #{dir}/package.json" }
    if changelog_section_found
      puts "\nChangelog: ✓ CHANGELOG.md section found for v#{released_npm_version}"
    else
      puts "\nChangelog: ⚠ No CHANGELOG.md section for v#{released_npm_version} — add one before releasing."
    end
    puts "\nTo actually release, run: rake \"release[#{released_gem_version}]\""
    return
  end

  puts "Published to npmjs.org:"
  puts "  - shakapacker@#{released_npm_version}"
  puts "  - shakapacker-webpack@#{released_npm_version}"
  puts "  - shakapacker-rspack@#{released_npm_version}"
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

def print_github_release_recovery(gem_version)
  puts "\nPARTIAL RELEASE: GitHub release synchronization failed after publication."
  puts "The Ruby gem, npm packages, and git tag were already published."
  puts "After fixing the GitHub release failure, run:"
  puts "bundle exec rake \"sync_github_release[#{gem_version}]\""
end

def perform_release(
  gem_version:,
  dry_run:,
  check_uncommitted: true,
  allow_version_policy_override: false,
  allow_ci_status_override: false,
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
    # Cheapest and most local of the gates, so it runs before the interactive npm login prompt.
    verify_node_modules!(gem_root: gem_root)
    verify_npm_auth
    verify_gh_auth(gem_root: gem_root)
  end

  requested_gem_version = gem_version.to_s.strip
  validate_requested_gem_version!(requested_gem_version)

  with_release_checkout(gem_root: gem_root, dry_run: dry_run) do |release_root|
    unless dry_run
      Shakapacker::Utils::Misc.sh_in_dir(release_root, "git pull --rebase")

      # The rebase can bring in dependency changes, staling the install the preflight just
      # verified. prepublishOnly would only discover that after release-it has tagged and
      # pushed, so re-verify the rebased tree here — still before the bump mutates anything.
      verify_node_modules!(gem_root: release_root)
    end

    # Gate on CI *after* the rebase so the validated commit is the one being released.
    validate_release_ci_status!(
      gem_root: release_root,
      allow_override: allow_ci_status_override,
      dry_run: dry_run
    )

    # An argument-less dry run refreshes only its throwaway worktree. Resolve the
    # implicit version here so it reads the refreshed changelog and gem version.
    if dry_run && requested_gem_version.empty?
      requested_gem_version = resolve_implicit_release_version(gem_root: release_root, dry_run: true)
    end

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
    refresh_release_root_lockfile(release_root)

    # Update spec/dummy lockfiles BEFORE release-it so they are included in the release commit.
    refresh_spec_dummy_lockfiles(release_root)

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

    if dry_run
      changelog_path = File.join(release_root, "CHANGELOG.md")
      changelog_section = extract_changelog_section(changelog_path: changelog_path, npm_version: released_npm_version)
      changelog_section_found = !changelog_section.nil?
    end

    # Bump the supplemental packages to match core. publish-packages.sh enforces
    # version lockstep across all three packages, but release-it only knows about
    # the root package.json — so we pre-bump the supplementals and stage them.
    # release-it picks up the staged files when it commits the version bump.
    #
    # `npm version` only rewrites the `version` field. The supplementals also
    # declare `"shakapacker": "~X.Y.Z"` as a regular dependency; without
    # rewriting that constraint here, a 10.1.0 → 10.2.0 bump would publish
    # supplementals declaring `~10.1.0` (resolves to >=10.1.0 <10.2.0 — unable
    # to install the new core). publish-packages.sh re-asserts both the
    # version AND the dependency constraint as a defense-in-depth check.
    supplemental_package_dirs.each do |pkg_dir|
      full_pkg_dir = File.join(release_root, pkg_dir)
      Shakapacker::Utils::Misc.sh_in_dir(
        full_pkg_dir,
        "npm version #{Shellwords.escape(npm_version)} --no-git-tag-version --allow-same-version"
      )
      bump_supplemental_core_dep(full_pkg_dir, npm_version)
    end
    supplemental_package_jsons = supplemental_package_dirs.map { |d| "#{d}/package.json" }
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "git add #{Shellwords.join(supplemental_package_jsons)}")

    # Use npx so maintainers don't need a globally installed `release-it` binary.
    # This avoids failures from shim managers (e.g. mise) when `release-it` isn't configured.
    # `--no-npm.publish` defers npm publishing to publish-packages.sh below, which
    # enforces lockstep across all three packages and publishes in the required
    # core-first order.
    release_it_command = +"npx --yes release-it #{Shellwords.escape(npm_version)}"
    release_it_command << " --no-npm.publish --no-git.requireCleanWorkingDir"
    release_it_command << " --dry-run --verbose" if dry_run
    npm_dist_tag = npm_dist_tag_for_version(npm_version)
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "NPM target (lockstep): shakapacker, shakapacker-webpack, shakapacker-rspack @ #{npm_version} (dist-tag: #{npm_dist_tag})"
    puts "release-it: bump versions, tag, push. publish-packages.sh: publish all three to npm."
    puts "Use the OTP for NPM! (one prompt per package)"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(release_root, release_it_command)

    # Publish all three npm packages in lockstep (core first, then supplementals).
    # publish-packages.sh re-validates version equality and skips packages that
    # are already on the registry, so it's safe to retry after a partial failure.
    publish_command = +"./scripts/publish-packages.sh"
    publish_command << " --tag #{Shellwords.escape(npm_dist_tag)}" unless npm_dist_tag == "latest"
    publish_command << " --dry-run" if dry_run
    Shakapacker::Utils::Misc.sh_in_dir(release_root, publish_command)

    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Use the OTP for RubyGems!"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(release_root, "gem release") unless dry_run

  end

  # Check changelog availability for the summary (both dry-run and live paths).
  sync_gem_version = released_gem_version || gem_version.to_s.strip
  if !dry_run && sync_gem_version && !sync_gem_version.empty?
    released_npm_version ||= Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(sync_gem_version)
    changelog_path = File.join(gem_root, "CHANGELOG.md")
    changelog_section = extract_changelog_section(changelog_path: changelog_path, npm_version: released_npm_version)
    changelog_section_found = !changelog_section.nil?

    begin
      sync_github_release_after_publish(gem_root: gem_root, gem_version: sync_gem_version, dry_run: dry_run,
                                        changelog_section: changelog_section)
    rescue StandardError, SystemExit => error
      raise if error.is_a?(SystemExit) && error.success?

      release_result = {
        dry_run: dry_run,
        released_gem_version: released_gem_version,
        released_npm_version: released_npm_version,
        changelog_section_found: changelog_section_found,
        staged_files: staged_files
      }
      print_release_summary(release_result)
      print_github_release_recovery(sync_gem_version)
      raise
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
4th argument: Override the CI status gate by passing 'true'.
              Equivalent to setting RELEASE_CI_STATUS_OVERRIDE=true.

The release aborts unless GitHub CI is green for the commit being released.
Use the CI override only for known-unrelated failures (for example an upstream
registry outage), never to paper over a real regression.

Examples:
- rake \"release\"                      # uses CHANGELOG.md version or patch bump
- rake \"release[9.6.0]\"
- rake \"release[9.6.0.rc.0]\"
- rake \"release[9.6.0,true]\"
- rake \"release[9.6.0,false,true]\"
- rake \"release[9.6.0,false,false,true]\"  # skip the CI gate
")
task :release, %i[gem_version dry_run override_version_policy override_ci_status] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])
  allow_override = version_policy_override_enabled?(args_hash[:override_version_policy])
  allow_ci_override = ci_status_override_enabled?(args_hash[:override_ci_status])

  requested_version = args_hash[:gem_version].to_s.strip
  if requested_version.empty? && !is_dry_run
    gem_root = File.expand_path("..", __dir__)
    requested_version = resolve_implicit_release_version(gem_root: gem_root, dry_run: false)
  end

  release_result = perform_release(
    gem_version: requested_version,
    dry_run: is_dry_run,
    allow_version_policy_override: allow_override,
    allow_ci_status_override: allow_ci_override
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
