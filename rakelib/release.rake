require_relative File.join("..", "lib", "shakapacker", "utils", "version_syntax_converter")
require_relative File.join("..", "lib", "shakapacker", "utils", "misc")

class RaisingMessageHandler
  def add_error(error)
    raise error
  end
end

desc("Releases both the gem and node package using the given version.

IMPORTANT: the gem version must be in valid rubygem format (no dashes).
It will be automatically converted to a valid yarn semver by the rake task
for the node package version. This only makes a difference for pre-release
versions such as `3.0.0.beta.1` (yarn version would be `3.0.0-beta.1`).

This task depends on the gem-release (ruby gem) and release-it (node package)
which are installed via `bundle install` and `yarn global add release-it`

1st argument: The new version in rubygem format (no dashes). Pass no argument to
              automatically perform a patch version bump.
2nd argument: Perform a dry run by passing 'true' as a second argument.

The task will:
1. Pull latest changes and bump versions
2. Publish to npm (requires OTP)
3. Publish to RubyGems (requires OTP)
4. Update spec/dummy lockfiles (runs bundle install and npm install)
5. Commit and push the lockfile updates

Note, accept defaults for npmjs options. Script will pause to get 2FA tokens.

Example: `rake create_release[2.1.0,false]`")
task :create_release, %i[gem_version dry_run] do |_t, args|
  # Check if there are uncommitted changes
  Shakapacker::Utils::Misc.uncommitted_changes?(RaisingMessageHandler.new)
  args_hash = args.to_hash

  is_dry_run = Shakapacker::Utils::Misc.object_to_boolean(args_hash[:dry_run])

  gem_version = args_hash.fetch(:gem_version, "")

  gem_root = File.expand_path("..", __dir__)

  npm_version = if gem_version.strip.empty?
    ""
                else
                  Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm(gem_version)
  end

  # See https://github.com/svenfuchs/gem-release
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git pull --rebase")
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "gem bump --no-commit #{gem_version.strip.empty? ? '' : %(--version #{gem_version})}")
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "bundle install")

  # Will bump the yarn version, commit, tag the commit, push to repo, and release on yarn
  release_it_command = +"release-it"
  release_it_command << " #{npm_version}" unless npm_version.strip.empty?
  release_it_command << " --npm.publish --no-git.requireCleanWorkingDir"
  release_it_command << " --dry-run --verbose" if is_dry_run
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "Use the OTP for NPM!"
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  Shakapacker::Utils::Misc.sh_in_dir(gem_root, release_it_command)

  # Release the new gem version
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "Use the OTP for RubyGems!"
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"

  Shakapacker::Utils::Misc.sh_in_dir(gem_root, "gem release") unless is_dry_run

  # Update spec/dummy lockfiles to use the new version
  spec_dummy_dir = File.join(gem_root, "spec", "dummy")
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  puts "Updating spec/dummy dependencies"
  puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
  Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "bundle install") unless is_dry_run
  # Note: spec/dummy uses npm (matching CI configuration)
  Shakapacker::Utils::Misc.sh_in_dir(spec_dummy_dir, "npm install") unless is_dry_run

  # Check if there are changes to spec/dummy lockfiles and commit them
  # Note: We check both npm and yarn lockfiles since the project supports multiple package managers for testing
  require "shellwords"
  lockfiles = ["spec/dummy/Gemfile.lock", "spec/dummy/package-lock.json", "spec/dummy/yarn.lock"]
  existing_lockfiles = lockfiles.select { |f| File.exist?(File.join(gem_root, f)) }
  changed_lockfiles = existing_lockfiles.select do |lockfile|
    changes_output = `git -C #{Shellwords.escape(gem_root)} status --porcelain -- #{Shellwords.escape(lockfile)}`
    !changes_output.strip.empty?
  end

  if !changed_lockfiles.empty? && !is_dry_run
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    puts "Committing and pushing spec/dummy lockfile changes: #{changed_lockfiles.join(', ')}"
    puts "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git add -- #{changed_lockfiles.join(' ')}")
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git commit -m 'Update spec/dummy lockfiles after release'")
    Shakapacker::Utils::Misc.sh_in_dir(gem_root, "git push")
  end
end
