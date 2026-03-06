require_relative File.join("..", "lib", "shakapacker", "utils", "version_syntax_converter")
require_relative File.join("..", "lib", "shakapacker", "utils", "misc")
require "shellwords"
require "tempfile"

class RaisingMessageHandler
  def add_error(error)
    raise error
  end
end

def verify_npm_auth(registry_url = "https://registry.npmjs.org/")
  result = `npm whoami --registry #{registry_url} 2>&1`
  unless $CHILD_STATUS.success?
    puts "⚠️  NPM authentication required!"
    puts "Please run: npm login --registry #{registry_url}"
    puts ""
    system("npm login --registry #{registry_url}")
    result = `npm whoami --registry #{registry_url} 2>&1`
    unless $CHILD_STATUS.success?
      abort "❌ NPM login failed! Please authenticate with npm before running the release."
    end
  end
  puts "✓ Logged in to NPM as: #{result.strip}"
end

def verify_gh_auth
  result = `gh auth status 2>&1`
  unless $CHILD_STATUS.success?
    abort "❌ GitHub CLI authentication required! Run `gh auth login` and retry.\n\n#{result}"
  end
  puts "✓ GitHub CLI authenticated"
end

def current_gem_version(gem_root)
  version_file = File.join(gem_root, "lib", "shakapacker", "version.rb")
  content = File.read(version_file)
  match = content.match(/VERSION = "([^"]+)"/)
  abort "❌ Unable to read current gem version from #{version_file}" unless match

  match[1]
end

def prerelease_gem_version?(gem_version)
  gem_version.match?(/\A\d+\.\d+\.\d+\.(beta|rc)\.\d+\z/)
end

def extract_changelog_section(changelog_path:, npm_version:)
  lines = File.readlines(changelog_path)
  section_header = /^## \[v#{Regexp.escape(npm_version)}\]/
  start_index = lines.index { |line| line.match?(section_header) }
  return nil unless start_index

  end_index = ((start_index + 1)...lines.length).find { |idx| lines[idx].start_with?("## [") } || lines.length
  lines[start_index...end_index].join.rstrip
end

def publish_or_update_github_release(gem_root:, npm_version:, gem_version:, dry_run:)
  return if dry_run
  return if Shakapacker::Utils::Misc.object_to_boolean(ENV["SKIP_GITHUB_RELEASE"])

  verify_gh_auth

  changelog_path = File.join(gem_root, "CHANGELOG.md")
  notes = extract_changelog_section(changelog_path:, npm_version:)
  unless notes
    abort "❌ Could not find `## [v#{npm_version}]` in CHANGELOG.md. Add that section or set SKIP_GITHUB_RELEASE=true."
  end

  tag = "v#{npm_version}"
  title = tag
  prerelease_flag = prerelease_gem_version?(gem_version) ? " --prerelease" : ""

  Tempfile.create(["shakapacker-release-notes-", ".md"]) do |tmp|
    tmp.write(notes)
    tmp.flush

    tag_escaped = Shellwords.escape(tag)
    title_escaped = Shellwords.escape(title)
    notes_file_escaped = Shellwords.escape(tmp.path)
    view_command = "cd #{Shellwords.escape(gem_root)} && gh release view #{tag_escaped} >/dev/null 2>&1"
    release_exists = system(view_command)

    release_command = if release_exists
      "gh release edit #{tag_escaped} --title #{title_escaped} --notes-file #{notes_file_escaped}#{prerelease_flag}"
    else
      "gh release create #{tag_escaped} --title #{title_escaped} --notes-file #{notes_file_escaped}#{prerelease_flag}"
    end

    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Publishing GitHub release #{tag}#{prerelease_gem_version?(gem_version) ? ' (prerelease)' : ''}"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, release_command)
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

def perform_release(gem_version:, dry_run:)
  Shakapacker::Utils::Misc.uncommitted_changes?(RaisingMessageHandler.new)
  gem_root = File.expand_path("..", __dir__)

  unless dry_run
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "PRE-FLIGHT CHECKS"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    verify_npm_auth
  end

  requested_gem_version = gem_version.to_s.strip

  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git pull --rebase")
  bump_command = if requested_gem_version.empty?
    "gem bump --no-commit"
  else
    "gem bump --no-commit --version #{requested_gem_version}"
  end
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, bump_command)
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "bundle install")

  resolved_gem_version = current_gem_version(gem_root)
  npm_version = Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(resolved_gem_version)

  release_it_command = +"release-it #{npm_version}"
  release_it_command << " --npm.publish --no-git.requireCleanWorkingDir"
  release_it_command << " --dry-run --verbose" if dry_run
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "Use the OTP for NPM!"
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, release_it_command)

  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "Use the OTP for RubyGems!"
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "gem release") unless dry_run

  spec_dummy_dir = File.join(gem_root, "spec", "dummy")
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "Updating spec/dummy dependencies"
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "bundle install") unless dry_run
  Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "npm install") unless dry_run

  lockfiles = ["spec/dummy/Gemfile.lock", "spec/dummy/package-lock.json", "spec/dummy/yarn.lock"]
  existing_lockfiles = lockfiles.select { |f| File.exist?(File.join(gem_root, f)) }
  changed_lockfiles = existing_lockfiles.select do |lockfile|
    changes_output = `git -C #{Shellwords.escape(gem_root)} status --porcelain -- #{Shellwords.escape(lockfile)}`
    !changes_output.strip.empty?
  end

  if !changed_lockfiles.empty? && !dry_run
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Committing and pushing spec/dummy lockfile changes: #{changed_lockfiles.join(', ')}"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git add -- #{changed_lockfiles.join(' ')}")
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git commit -m 'Update spec/dummy lockfiles after release'")
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git push")
  end

  publish_or_update_github_release(gem_root:, npm_version:, gem_version: resolved_gem_version, dry_run:)
end

desc("Releases both the gem and node package using the given version.

IMPORTANT: the gem version must be in valid rubygem format (no dashes).
It will be automatically converted to npm semver by the rake task.

GitHub releases are created/updated from CHANGELOG.md.
For beta/rc versions, GitHub release is marked as prerelease automatically.

Arguments:
1st argument: The new version in rubygem format (example: 9.6.0.rc.0).
              Pass no argument to perform a patch bump.
2nd argument: Perform a dry run by passing 'true' as second argument.

Examples:
- rake create_release[9.6.0]
- rake create_release[9.6.0.rc.0]
- rake create_release[9.6.0,true]
")
task :create_release, %i[gem_version dry_run] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])
  perform_release(gem_version: args_hash[:gem_version], dry_run: is_dry_run)
end

desc("Creates the next prerelease automatically and then runs create_release.

Examples:
- rake create_prerelease[9.6.0,rc]       # -> 9.6.0.rc.0 or next rc index
- rake create_prerelease[9.6.0,beta]     # -> 9.6.0.beta.0 or next beta index
- rake create_prerelease[9.6.0,rc,true]  # dry run

Notes:
- Prompts for confirmation before continuing (set AUTO_CONFIRM=true to skip).
- Uses git tags to compute the next prerelease index.
")
task :create_prerelease, %i[base_version prerelease_type dry_run] do |_t, args|
  args_hash = args.to_hash
  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])
  gem_root = File.expand_path("..", __dir__)

  base_version = args_hash[:base_version].to_s.strip
  if base_version.empty?
    current_version = current_gem_version(gem_root)
    base_match = current_version.match(/\A(\d+\.\d+\.\d+)/)
    abort "❌ Could not infer base_version from current version #{current_version.inspect}" unless base_match

    base_version = base_match[1]
  end

  prerelease_type = args_hash[:prerelease_type].to_s.strip
  prerelease_type = "rc" if prerelease_type.empty?
  next_version = next_prerelease_gem_version(gem_root:, base_version:, prerelease_type:)

  puts "Computed next prerelease version: #{next_version}"
  confirm_or_abort!("Proceed with prerelease #{next_version}?") unless is_dry_run

  perform_release(gem_version: next_version, dry_run: is_dry_run)
end
