require "spec_helper"
require "rake"

release_rake_path = File.expand_path("../../rakelib/release.rake", __dir__)
load release_rake_path unless defined?(ensure_clean_worktree!)

RSpec.describe "release rake helpers" do
  describe "loading the rake file" do
    it "does not warn about reload-safe top-level definitions" do
      previous_verbose = $VERBOSE
      $VERBOSE = true

      expect do
        load File.expand_path("../../rakelib/release.rake", __dir__)
      end.not_to output(
        /GITHUB_REPO_SLUG_PATTERN|CI_PASSING_CONCLUSIONS|CONDITIONAL_MAIN_PUSH_WORKFLOWS|REQUIRED_RELEASE_NODE_BINARIES|AbortingMessageHandler/
      ).to_stderr
    ensure
      $VERBOSE = previous_verbose
    end
  end

  describe "#ensure_clean_worktree!" do
    it "aborts with a user-facing message instead of raising a backtrace-producing error" do
      allow(Shakapacker::Utils::Misc).to receive(:uncommitted_changes?) do |message_handler|
        message_handler.add_error("You have uncommitted code")
      end

      expect do
        expect { ensure_clean_worktree! }.to raise_error(SystemExit)
      end.to output("❌ You have uncommitted code\n").to_stderr
    end
  end

  describe "#verify_node_modules!" do
    around do |example|
      Dir.mktmpdir("shakapacker-node-modules-spec") do |tmpdir|
        @node_modules_gem_root = tmpdir
        example.run
      end
    end

    def create_node_bin(name)
      bin_dir = File.join(@node_modules_gem_root, "node_modules", ".bin")
      FileUtils.mkdir_p(bin_dir)
      bin_path = File.join(bin_dir, name)
      File.write(bin_path, "#!/bin/sh\n")
      FileUtils.chmod(0o755, bin_path)
    end

    def create_complete_install(declared: { "webpack-merge" => "^5.8.0" }, recorded: nil, present: nil)
      REQUIRED_RELEASE_NODE_BINARIES.each { |binary| create_node_bin(binary) }
      File.write(
        File.join(@node_modules_gem_root, "package.json"),
        JSON.generate("dependencies" => declared)
      )
      patterns = recorded || declared.map { |name, spec| "#{name}@#{spec}" }
      write_yarn_integrity(JSON.generate("topLevelPatterns" => patterns))
      (present || declared.keys).each do |name|
        FileUtils.mkdir_p(File.join(@node_modules_gem_root, "node_modules", name))
      end
    end

    def write_yarn_integrity(contents)
      File.write(File.join(@node_modules_gem_root, "node_modules", ".yarn-integrity"), contents)
    end

    it "aborts naming yarn install when node_modules is not installed" do
      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/Node dependencies are not installed.*Run `yarn install` and retry/m).to_stderr
    end

    it "aborts naming yarn install when a prepublishOnly binary is missing" do
      create_node_bin("prettier")

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/Node dependencies are incomplete: tsc.*Run `yarn install` and retry/m).to_stderr
    end

    it "aborts naming yarn install when no install ever finished" do
      REQUIRED_RELEASE_NODE_BINARIES.each { |binary| create_node_bin(binary) }

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/incompletely installed.*Run `yarn install` and retry/m).to_stderr
    end

    it "aborts naming yarn install when package.json declares a dependency the install never saw" do
      create_complete_install(
        declared: { "webpack-merge" => "^5.8.0", "js-yaml" => "^4.1.0" },
        recorded: ["webpack-merge@^5.8.0"]
      )

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/stale: package\.json declares js-yaml@\^4\.1\.0.*Run `yarn install` and retry/m).to_stderr
    end

    it "tolerates leftover entries in the integrity marker" do
      create_complete_install(
        declared: { "webpack-merge" => "^5.8.0" },
        recorded: ["webpack-merge@^5.8.0", "removed-package@^1.0.0"]
      )

      expect do
        # `abort` raises SystemExit, which would otherwise tear down the whole run instead of
        # failing this example — a regression here must surface as a normal failure.
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.not_to raise_error
      end.to output(/✓ Node dependencies installed/).to_stdout
    end

    it "skips drift detection when the integrity marker is not in a comparable format" do
      create_complete_install
      write_yarn_integrity("not json at all")

      expect do
        # `abort` raises SystemExit, which would otherwise tear down the whole run instead of
        # failing this example — a regression here must surface as a normal failure.
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.not_to raise_error
      end.to output(/✓ Node dependencies installed/).to_stdout
    end

    it "aborts when a declared package is missing from the installed tree" do
      create_complete_install(
        declared: { "webpack-merge" => "^5.8.0", "js-yaml" => "^4.1.0" },
        present: ["webpack-merge"]
      )

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/damaged: js-yaml declared in package\.json but missing.*Run `yarn install`/m).to_stderr
    end

    it "still checks package presence when the integrity marker cannot be compared" do
      create_complete_install(
        declared: { "webpack-merge" => "^5.8.0", "js-yaml" => "^4.1.0" },
        present: ["webpack-merge"]
      )
      write_yarn_integrity("not json at all")

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/damaged: js-yaml/m).to_stderr
    end

    it "aborts cleanly when a dependency section is not an object" do
      create_complete_install
      File.write(
        File.join(@node_modules_gem_root, "package.json"),
        JSON.generate("dependencies" => "webpack-merge@^5.8.0")
      )

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/malformed dependencies section: expected an object.*got String/m).to_stderr
    end

    # An Array survives `.map`, so without the shape check this one yields garbage patterns
    # instead of raising — the drift comparison would then trust them.
    it "aborts cleanly when an optional dependency section is an array" do
      create_complete_install
      File.write(
        File.join(@node_modules_gem_root, "package.json"),
        JSON.generate(
          "dependencies" => { "webpack-merge" => "^5.8.0" },
          "optionalDependencies" => ["fsevents"]
        )
      )

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/malformed optionalDependencies section.*got Array/m).to_stderr
    end

    # npm lets an optionalDependencies entry override a dependencies entry of the same name, so
    # this package may be legitimately absent — aborting on it would block every release.
    it "does not require a dependency that is also declared optional" do
      REQUIRED_RELEASE_NODE_BINARIES.each { |binary| create_node_bin(binary) }
      File.write(
        File.join(@node_modules_gem_root, "package.json"),
        JSON.generate(
          "dependencies" => { "fsevents" => "^2.3.0" },
          "optionalDependencies" => { "fsevents" => "^2.3.0" }
        )
      )
      write_yarn_integrity(JSON.generate("topLevelPatterns" => ["fsevents@^2.3.0"]))

      expect do
        # `abort` raises SystemExit, which would otherwise tear down the whole run instead of
        # failing this example — a regression here must surface as a normal failure.
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.not_to raise_error
      end.to output(/✓ Node dependencies installed/).to_stdout
    end

    it "does not require optional dependencies to be present" do
      REQUIRED_RELEASE_NODE_BINARIES.each { |binary| create_node_bin(binary) }
      File.write(
        File.join(@node_modules_gem_root, "package.json"),
        JSON.generate("optionalDependencies" => { "fsevents" => "^2.3.0" })
      )
      write_yarn_integrity(JSON.generate("topLevelPatterns" => ["fsevents@^2.3.0"]))

      expect do
        # `abort` raises SystemExit, which would otherwise tear down the whole run instead of
        # failing this example — a regression here must surface as a normal failure.
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.not_to raise_error
      end.to output(/✓ Node dependencies installed/).to_stdout
    end

    it "skips drift detection when the integrity marker cannot be read" do
      create_complete_install
      integrity_path = File.join(@node_modules_gem_root, "node_modules", ".yarn-integrity")
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(integrity_path).and_raise(Errno::EACCES)

      expect do
        # `abort` raises SystemExit, which would otherwise tear down the whole run instead of
        # failing this example — a regression here must surface as a normal failure.
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.not_to raise_error
      end.to output(/✓ Node dependencies installed/).to_stdout
    end

    # Valid JSON that is not an object. Indexing an Array/Integer/true/nil root raises, and a
    # String root is quieter still: every section reads as nil, so the check would pass vacuously.
    it "aborts when package.json parses to something other than an object" do
      create_complete_install
      manifest_path = File.join(@node_modules_gem_root, "package.json")

      ["[]", '"x"', "42", "true", "null"].each do |root|
        File.write(manifest_path, root)

        expect do
          expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
        end.to output(/package\.json is not a JSON object.*Fix package\.json and retry/m).to_stderr
      end
    end

    it "aborts with an actionable message when package.json cannot be parsed" do
      create_complete_install
      File.write(File.join(@node_modules_gem_root, "package.json"), "{ not json")

      expect do
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.to raise_error(SystemExit)
      end.to output(/Unable to read .*package\.json for the node dependency check/m).to_stderr
    end

    it "passes when the install is complete and matches package.json" do
      create_complete_install

      expect do
        # `abort` raises SystemExit, which would otherwise tear down the whole run instead of
        # failing this example — a regression here must surface as a normal failure.
        expect { verify_node_modules!(gem_root: @node_modules_gem_root) }.not_to raise_error
      end.to output(/✓ Node dependencies installed/).to_stdout
    end

    # Guards the dangerous direction: a false abort here would block a legitimate release.
    it "accepts the repository's own installed node_modules" do
      repo_root = File.expand_path("../..", __dir__)
      unless File.directory?(File.join(repo_root, "node_modules", ".bin"))
        skip "node_modules is not installed in this environment"
      end

      expect do
        expect { verify_node_modules!(gem_root: repo_root) }.not_to raise_error
      end.to output(/✓ Node dependencies installed/).to_stdout
    end
  end

  describe "#github_repo_slug" do
    def stub_origin_url(url, success: true)
      status = double("status", success?: success)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/repo", "remote", "get-url", "origin")
        .and_return(["#{url}\n", status])
    end

    it "extracts GitHub repo slugs from supported remote URL formats" do
      {
        "git@github.com:shakacode/shakapacker.git" => "shakacode/shakapacker",
        "ssh://git@github.com/shakacode/shakapacker.git" => "shakacode/shakapacker",
        "https://github.com/shakacode/shakapacker.git" => "shakacode/shakapacker",
        "https://token@github.com/shakacode/shakapacker.git" => "shakacode/shakapacker",
        "git://github.com/shakacode/shakapacker.git" => "shakacode/shakapacker",
        "github.com/shakacode/shakapacker" => "shakacode/shakapacker"
      }.each do |origin_url, expected_slug|
        stub_origin_url(origin_url)

        expect(github_repo_slug("/repo")).to eq(expected_slug)
      end
    end

    it "rejects non-GitHub remotes" do
      stub_origin_url("https://example.com/shakacode/shakapacker.git")

      expect do
        expect { github_repo_slug("/repo") }.to raise_error(SystemExit)
      end.to output(/Unable to determine GitHub repository/).to_stderr
    end

    it "rejects unsafe GitHub slug characters" do
      stub_origin_url("git@github.com:shakacode/shakapacker;touch.git")

      expect do
        expect { github_repo_slug("/repo") }.to raise_error(SystemExit)
      end.to output(/repository slug "shakacode\/shakapacker;touch" .* is invalid/).to_stderr
    end
  end

  describe "#refresh_spec_dummy_lockfiles" do
    # Tracks whether each command ran inside Bundler.with_unbundled_env. `bundle install`
    # must, or it re-resolves the root Gemfile (BUNDLE_GEMFILE is inherited from
    # `bundle exec rake release`) and leaves spec/dummy/Gemfile.lock at the pre-bump version.
    let(:commands) { [] }

    before do
      unbundled = false

      allow(Bundler).to receive(:with_unbundled_env) do |&block|
        unbundled = true
        begin
          block.call
        ensure
          unbundled = false
        end
      end

      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |dir, command|
        commands << { dir: dir, command: command, unbundled: unbundled }
      end
    end

    it "runs the spec/dummy bundle install with the parent bundler env removed" do
      refresh_spec_dummy_lockfiles("/repo")

      expect(commands).to include(
        { dir: "/repo/spec/dummy", command: "bundle install", unbundled: true }
      )
    end

    it "refreshes the yarn and npm lockfiles in spec/dummy" do
      refresh_spec_dummy_lockfiles("/repo")

      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir).with("/repo/spec/dummy", "yarn install")
      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir).with("/repo/spec/dummy", "npm install")
    end
  end

  describe "#refresh_release_root_lockfile" do
    it "runs the release-root bundle install with the parent bundler env removed" do
      unbundled = false
      commands = []

      allow(Bundler).to receive(:with_unbundled_env) do |&block|
        unbundled = true
        begin
          block.call
        ensure
          unbundled = false
        end
      end
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |dir, command|
        commands << { dir: dir, command: command, unbundled: unbundled }
      end

      refresh_release_root_lockfile("/tmp/release-worktree")

      expect(commands).to eq(
        [{ dir: "/tmp/release-worktree", command: "bundle install", unbundled: true }]
      )
    end
  end

  describe "#with_release_checkout" do
    # Pinned so the throwaway branch name is predictable; the random suffix itself is covered
    # by "names the dry-run branch with a random suffix ..." below.
    let(:dry_run_branch) { "release-dry-run-#{Process.pid}-abcd1234" }

    before do
      allow(SecureRandom).to receive(:hex).with(4).and_return("abcd1234")
      allow(Dir).to receive(:mktmpdir)
        .with("shakapacker-release-dry-run")
        .and_yield("/tmp/shakapacker-release")
      successful_status = double("status", success?: true)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "fetch", "origin", "main")
        .and_return(["", successful_status])
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "rebase", "origin/main")
        .and_return(["", successful_status])
      # `anything` for the branch so the random-suffix example can call the real SecureRandom;
      # the exact name is still asserted via `have_received`.
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "branch",
              "--set-upstream-to=origin/main", anything)
        .and_return(["", successful_status])
    end

    it "refreshes the dry-run worktree from origin/main before evaluating the release" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      yielded_root = nil
      with_release_checkout(gem_root: "/repo", dry_run: true) { |release_root| yielded_root = release_root }

      expect(yielded_root).to eq("/tmp/shakapacker-release/worktree")
      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", "git worktree prune").ordered
      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", "git worktree add -b #{dry_run_branch} " \
                      "/tmp/shakapacker-release/worktree HEAD").ordered
      expect(Open3).to have_received(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "fetch", "origin", "main").ordered
      expect(Open3).to have_received(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "rebase", "origin/main").ordered
      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", "git worktree remove --force /tmp/shakapacker-release/worktree").ordered
    end

    it "tracks origin/main so release-it finds an upstream for the dry-run branch" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }

      expect(Open3).to have_received(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "branch",
              "--set-upstream-to=origin/main", dry_run_branch)
    end

    it "aborts with an actionable message when the dry-run branch cannot track origin/main" do
      failed_status = double("status", success?: false)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "branch",
              "--set-upstream-to=origin/main", dry_run_branch)
        .and_return(["the requested upstream branch 'origin/main' does not exist\n", failed_status])
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) { "unreachable" }
        end.to raise_error(SystemExit)
      end.to output(/Unable to track origin\/main from the dry-run branch.*does not exist/m).to_stderr
    end

    it "deletes the throwaway dry-run branch so no stray branches are left behind" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }

      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", "git worktree remove --force /tmp/shakapacker-release/worktree").ordered
      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", "git branch -D #{dry_run_branch}").ordered
    end

    # `sh_in_dir` raises on a non-zero exit, so chaining the two cleanup calls would let a
    # failed `worktree remove` skip the branch deletion entirely.
    it "still deletes the throwaway branch when removing the worktree fails" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |_dir, command|
        raise "cleanup failed" if command.include?("git worktree remove")

        true
      end

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }
        end.to raise_error(RuntimeError, "cleanup failed")
      end.to output(/Failed to clean up dry-run release worktree/).to_stderr

      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", "git branch -D #{dry_run_branch}")
    end

    it "warns about every cleanup step that fails rather than stopping at the first" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |_dir, command|
        raise "cleanup failed" if command.include?("git worktree remove") || command.include?("git branch -D")

        true
      end

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) do
            raise "release failed"
          end
        end.to raise_error(RuntimeError, "release failed")
      end.to output(
        /git worktree remove --force .*\n.*\n?.*git branch -D #{Regexp.escape(dry_run_branch)}/m
      ).to_stderr
    end

    it "prunes stale worktree registrations before adding the dry-run worktree" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }

      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", "git worktree prune").ordered
      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", a_string_including("git worktree add")).ordered
    end

    # A leaked branch stays checked out in the killed run's registered worktree, and git
    # refuses to reuse that name even under `-B`. A fresh name per run cannot collide.
    it "names the dry-run branch with a random suffix so a leaked branch cannot collide" do
      allow(SecureRandom).to receive(:hex).with(4).and_call_original
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }

      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir)
        .with("/repo", match(/\Agit worktree add -b release-dry-run-#{Process.pid}-[0-9a-f]{8} /))
    end

    it "never creates the dry-run worktree with a detached HEAD" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }

      expect(Shakapacker::Utils::Misc).not_to have_received(:sh_in_dir)
        .with("/repo", a_string_including("git worktree add --detach"))
    end

    it "aborts with an actionable message when the dry-run fetch fails" do
      failed_status = double("status", success?: false)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "fetch", "origin", "main")
        .and_return(["network unavailable\n", failed_status])
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) { "unreachable" }
        end.to raise_error(SystemExit)
      end.to output(/Unable to fetch origin\/main for the dry run.*network unavailable/m).to_stderr
    end

    it "aborts with an actionable message when the dry-run rebase fails" do
      successful_status = double("status", success?: true)
      failed_status = double("status", success?: false)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "fetch", "origin", "main")
        .and_return(["", successful_status])
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/tmp/shakapacker-release/worktree", "rebase", "origin/main")
        .and_return(["CONFLICT in release files\n", failed_status])
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) { "unreachable" }
        end.to raise_error(SystemExit)
      end.to output(/Unable to rebase the dry run onto origin\/main.*CONFLICT in release files/m).to_stderr
    end

    it "preserves the release failure when dry-run worktree cleanup also fails" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |_dir, command|
        raise "cleanup failed" if command.include?("git worktree remove")

        true
      end

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) do
            raise "release failed"
          end
        end.to raise_error(RuntimeError, "release failed")
      end.to output(/Failed to clean up dry-run release worktree/).to_stderr
    end

    it "preserves the release failure when cleanup raises outside StandardError" do
      cleanup_error_class = Class.new(Exception)
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |_dir, command|
        raise cleanup_error_class, "cleanup failed" if command.include?("git worktree remove")

        true
      end

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) do
            raise "release failed"
          end
        end.to raise_error(RuntimeError, "release failed")
      end.to output(/Failed to clean up dry-run release worktree/).to_stderr
    end

    it "raises cleanup failures when the dry run itself succeeded" do
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |_dir, command|
        raise "cleanup failed" if command.include?("git worktree remove")

        true
      end

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }
        end.to raise_error(RuntimeError, "cleanup failed")
      end.to output(/Failed to clean up dry-run release worktree/).to_stderr
    end
  end

  # release-it runs `git symbolic-ref HEAD` and aborts the dry run when it fails, so this
  # exercises real git rather than asserting on the command string alone.
  describe "#with_release_checkout against a real repository" do
    def run_git!(*args)
      output, status = Open3.capture2e("git", *args)
      raise "git #{args.join(' ')} failed:\n#{output}" unless status.success?

      output
    end

    def build_repository(sandbox)
      origin = File.join(sandbox, "origin.git")
      repo = File.join(sandbox, "repo")

      run_git!("init", "--quiet", "--bare", "--initial-branch=main", origin)
      run_git!("clone", "--quiet", origin, repo)
      run_git!("-C", repo, "config", "user.email", "release@example.com")
      run_git!("-C", repo, "config", "user.name", "Release Bot")
      File.write(File.join(repo, "README.md"), "dry run\n")
      run_git!("-C", repo, "add", "README.md")
      run_git!("-C", repo, "commit", "--quiet", "-m", "Initial commit")
      run_git!("-C", repo, "push", "--quiet", "origin", "main")

      repo
    end

    # Pinned so the throwaway branch name is predictable, and so the leaked-worktree tests can
    # stage a leftover under the exact name this run will try to use.
    let(:dry_run_branch) { "release-dry-run-#{Process.pid}-abcd1234" }

    before do
      allow(SecureRandom).to receive(:hex).with(4).and_return("abcd1234")
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |dir, *shell_commands|
        shell_commands.flatten.each do |shell_command|
          output, status = Open3.capture2e("bash", "-c", "cd #{Shellwords.escape(dir)} && #{shell_command}")
          raise "sh_in_dir failed: #{shell_command}\n#{output}" unless status.success?
        end
      end
    end

    it "gives the dry-run worktree a symbolic HEAD instead of a detached one" do
      Dir.mktmpdir("shakapacker-release-symbolic-head") do |sandbox|
        repo = build_repository(sandbox)
        symbolic_ref_output = nil
        symbolic_ref_succeeded = nil

        with_release_checkout(gem_root: repo, dry_run: true) do |release_root|
          symbolic_ref_output, status = Open3.capture2e("git", "-C", release_root, "symbolic-ref", "HEAD")
          symbolic_ref_succeeded = status.success?
        end

        expect(symbolic_ref_succeeded).to be(true)
        expect(symbolic_ref_output).not_to include("not a symbolic ref")
        expect(symbolic_ref_output.strip).to eq("refs/heads/#{dry_run_branch}")
      end
    end

    # A hard-killed dry run skips the ensure block and leaves its worktree registered with the
    # branch still checked out. git refuses to reuse a branch held by another worktree — `-B`
    # included, since it cannot claim one — so the new run must not depend on that name being
    # free. It also prunes the registration once the directory is gone.
    it "still runs and prunes when a hard-killed run leaked a worktree registration" do
      Dir.mktmpdir("shakapacker-release-symbolic-head") do |sandbox|
        repo = build_repository(sandbox)
        leaked_worktree = File.join(sandbox, "leaked")
        run_git!("-C", repo, "worktree", "add", "-b", "release-dry-run-#{Process.pid}-deadbeef",
                 leaked_worktree, "HEAD")
        FileUtils.rm_rf(leaked_worktree)
        symbolic_ref_output = nil

        expect do
          with_release_checkout(gem_root: repo, dry_run: true) do |release_root|
            symbolic_ref_output = run_git!("-C", release_root, "symbolic-ref", "HEAD")
          end
        end.not_to raise_error

        expect(symbolic_ref_output.strip).to eq("refs/heads/#{dry_run_branch}")
        expect(run_git!("-C", repo, "branch", "--list")).not_to include(dry_run_branch)
        expect(run_git!("-C", repo, "worktree", "list")).not_to include(leaked_worktree)
      end
    end

    # The leftover directory is still present here, so pruning cannot reclaim it. Only the
    # per-run random suffix keeps the new branch name from colliding.
    it "still runs when an earlier dry-run worktree is still registered and present" do
      Dir.mktmpdir("shakapacker-release-symbolic-head") do |sandbox|
        repo = build_repository(sandbox)
        leaked_worktree = File.join(sandbox, "leaked")
        run_git!("-C", repo, "worktree", "add", "-b", "release-dry-run-#{Process.pid}-deadbeef",
                 leaked_worktree, "HEAD")
        symbolic_ref_output = nil

        expect do
          with_release_checkout(gem_root: repo, dry_run: true) do |release_root|
            symbolic_ref_output = run_git!("-C", release_root, "symbolic-ref", "HEAD")
          end
        end.not_to raise_error

        expect(symbolic_ref_output.strip).to eq("refs/heads/#{dry_run_branch}")
      end
    end

    it "configures an upstream on the dry-run branch, which release-it also requires" do
      Dir.mktmpdir("shakapacker-release-symbolic-head") do |sandbox|
        repo = build_repository(sandbox)
        upstream = nil

        with_release_checkout(gem_root: repo, dry_run: true) do |release_root|
          upstream = run_git!(
            "-C", release_root, "for-each-ref", "--format=%(upstream:short)",
            "refs/heads/#{dry_run_branch}"
          )
        end

        expect(upstream.strip).to eq("origin/main")
      end
    end

    it "leaves no throwaway branch or worktree behind after the dry run" do
      Dir.mktmpdir("shakapacker-release-symbolic-head") do |sandbox|
        repo = build_repository(sandbox)

        with_release_checkout(gem_root: repo, dry_run: true) { "ok" }

        expect(run_git!("-C", repo, "branch", "--list")).not_to include(dry_run_branch)
        expect(run_git!("-C", repo, "worktree", "list").lines.size).to eq(1)
      end
    end
  end

  describe "#perform_release" do
    it "aborts before the version bump, commit, tag, or push when node_modules is missing" do
      gem_root = File.expand_path("../..", __dir__)
      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:verify_npm_auth)
      allow(self).to receive(:verify_gh_auth)
      allow(self).to receive(:with_release_checkout)
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with(File.join(gem_root, "node_modules", ".bin")).and_return(false)

      expect do
        expect do
          perform_release(gem_version: "10.4.0", dry_run: false)
        end.to raise_error(SystemExit) { |error| expect(error.status).not_to eq(0) }
      end.to output(/Node dependencies are not installed.*Run `yarn install` and retry/m).to_stderr

      # Nothing may run before the abort: the bump, commit, tag, and push all go through
      # the release checkout and sh_in_dir.
      expect(self).not_to have_received(:with_release_checkout)
      expect(Shakapacker::Utils::Misc).not_to have_received(:sh_in_dir)
      expect(self).not_to have_received(:verify_npm_auth)
    end

    it "re-verifies node dependencies after the rebase, before the version bump" do
      gem_root = File.expand_path("../..", __dir__)
      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:verify_npm_auth)
      allow(self).to receive(:verify_gh_auth)
      allow(self).to receive(:with_release_checkout).and_yield("/release")
      allow(self).to receive(:validate_release_ci_status!)
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)
      # Clean at preflight, stale once the rebase has landed dependency changes.
      allow(self).to receive(:verify_node_modules!).with(gem_root: gem_root)
      allow(self).to receive(:verify_node_modules!).with(gem_root: "/release").and_raise(SystemExit.new(1))

      expect do
        perform_release(gem_version: "10.4.0", dry_run: false)
      end.to raise_error(SystemExit) { |error| expect(error.status).not_to eq(0) }

      expect(Shakapacker::Utils::Misc).to have_received(:sh_in_dir).with("/release", "git pull --rebase")
      expect(Shakapacker::Utils::Misc).not_to have_received(:sh_in_dir).with("/release", /gem bump/)
      expect(self).not_to have_received(:validate_release_ci_status!)
    end

    it "does not re-verify node dependencies inside the dry-run scratch worktree" do
      allow(self).to receive(:with_release_checkout).and_yield("/refreshed")
      allow(self).to receive(:validate_release_ci_status!)
      allow(self).to receive(:verify_node_modules!)
      allow(self).to receive(:target_gem_version).and_return("10.4.0")
      allow(self).to receive(:warn_changelog_missing)
      allow(self).to receive(:validate_release_version_policy!)
      allow(self).to receive(:refresh_release_root_lockfile)
      allow(self).to receive(:refresh_spec_dummy_lockfiles)
      allow(self).to receive(:current_gem_version).with("/refreshed").and_return("10.4.0")
      allow(self).to receive(:bump_supplemental_core_dep)
      allow(self).to receive(:extract_changelog_section).and_return("release notes")
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      perform_release(gem_version: "10.4.0", dry_run: true, check_uncommitted: false)

      # The scratch worktree never gets its own `yarn install`, so verifying it would abort
      # every dry run. That gap is tracked separately.
      expect(self).not_to have_received(:verify_node_modules!)
    end

    it "does not print a publication summary when GitHub auth fails during preflight" do
      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:verify_node_modules!)
      allow(self).to receive(:verify_npm_auth)
      allow(self).to receive(:verify_gh_auth).and_raise(SystemExit.new(1))

      expect do
        expect do
          perform_release(gem_version: "10.4.0", dry_run: false)
        end.to raise_error(SystemExit) { |error| expect(error.status).not_to eq(0) }
      end.not_to output(/RELEASE COMPLETE!|PARTIAL RELEASE|sync_github_release/).to_stdout
    end

    it "prints the release summary and recovery command before re-raising a post-publish GitHub auth failure" do
      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:with_release_checkout).and_yield("/release")
      allow(self).to receive(:verify_node_modules!)
      allow(self).to receive(:verify_npm_auth)
      auth_error = SystemExit.new(1, "GitHub authentication expired")
      expect(self).to receive(:verify_gh_auth).with(gem_root: anything).ordered
      expect(self).to receive(:verify_gh_auth).with(gem_root: anything).ordered
        .and_raise(auth_error)
      allow(self).to receive(:validate_release_ci_status!)
      allow(self).to receive(:target_gem_version).and_return("10.4.0.rc.1")
      allow(self).to receive(:warn_changelog_missing)
      allow(self).to receive(:validate_release_version_policy!)
      allow(self).to receive(:refresh_release_root_lockfile)
      allow(self).to receive(:refresh_spec_dummy_lockfiles)
      allow(self).to receive(:current_gem_version).with("/release").and_return("10.4.0.rc.1")
      allow(self).to receive(:bump_supplemental_core_dep)
      allow(self).to receive(:extract_changelog_section).and_return("release notes")
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      expect do
        expect do
          perform_release(gem_version: "10.4.0.rc.1", dry_run: false)
        end.to raise_error(SystemExit) { |error| expect(error).to equal(auth_error) }
      end.to output(
        /RELEASE COMPLETE!.*shakapacker@10\.4\.0-rc\.1.*shakapacker 10\.4\.0\.rc\.1.*bundle exec rake "sync_github_release\[10\.4\.0\.rc\.1\]"/m
      ).to_stdout
    end

    it "prints the release summary and recovery command before re-raising a post-publish StandardError" do
      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:with_release_checkout).and_yield("/release")
      allow(self).to receive(:verify_node_modules!)
      allow(self).to receive(:verify_npm_auth)
      allow(self).to receive(:verify_gh_auth)
      allow(self).to receive(:validate_release_ci_status!)
      allow(self).to receive(:target_gem_version).and_return("10.4.0")
      allow(self).to receive(:warn_changelog_missing)
      allow(self).to receive(:validate_release_version_policy!)
      allow(self).to receive(:refresh_release_root_lockfile)
      allow(self).to receive(:refresh_spec_dummy_lockfiles)
      allow(self).to receive(:current_gem_version).with("/release").and_return("10.4.0")
      allow(self).to receive(:bump_supplemental_core_dep)
      allow(self).to receive(:extract_changelog_section).and_return("release notes")
      github_error = RuntimeError.new("GitHub API failed")
      allow(self).to receive(:sync_github_release_after_publish).and_raise(github_error)
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      expect do
        expect do
          perform_release(gem_version: "10.4.0", dry_run: false)
        end.to raise_error(RuntimeError) { |error| expect(error).to equal(github_error) }
      end.to output(
        /RELEASE COMPLETE!.*bundle exec rake "sync_github_release\[10\.4\.0\]"/m
      ).to_stdout
    end

    it "does not label a successful post-publish SystemExit as a partial release" do
      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:with_release_checkout).and_yield("/release")
      allow(self).to receive(:verify_node_modules!)
      allow(self).to receive(:verify_npm_auth)
      allow(self).to receive(:verify_gh_auth)
      allow(self).to receive(:validate_release_ci_status!)
      allow(self).to receive(:target_gem_version).and_return("10.4.0")
      allow(self).to receive(:warn_changelog_missing)
      allow(self).to receive(:validate_release_version_policy!)
      allow(self).to receive(:refresh_release_root_lockfile)
      allow(self).to receive(:refresh_spec_dummy_lockfiles)
      allow(self).to receive(:current_gem_version).with("/release").and_return("10.4.0")
      allow(self).to receive(:bump_supplemental_core_dep)
      allow(self).to receive(:extract_changelog_section).and_return("release notes")
      successful_exit = SystemExit.new(0)
      allow(self).to receive(:sync_github_release_after_publish).and_raise(successful_exit)
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)

      expect do
        expect do
          perform_release(gem_version: "10.4.0", dry_run: false)
        end.to raise_error(SystemExit) { |error| expect(error).to equal(successful_exit) }
      end.not_to output(/RELEASE COMPLETE!|PARTIAL RELEASE|sync_github_release/).to_stdout
    end

    it "resolves an implicit dry-run version from the refreshed release checkout" do
      allow(self).to receive(:ensure_clean_worktree!)
      allow(self).to receive(:with_release_checkout).and_yield("/refreshed")
      allow(self).to receive(:validate_release_ci_status!)
      allow(self).to receive(:extract_latest_changelog_version)
        .with(gem_root: "/refreshed")
        .and_return("10.4.0")
      allow(self).to receive(:current_gem_version).with("/refreshed").and_return("10.3.1")
      expect(self).to receive(:target_gem_version)
        .with(gem_root: "/refreshed", requested_gem_version: "10.4.0")
        .and_raise("stop after version resolution")

      expect do
        perform_release(gem_version: "", dry_run: true)
      end.to raise_error(RuntimeError, "stop after version resolution")
    end

    it "preserves the refreshed checkout changelog result in the dry-run summary" do
      allow(self).to receive(:with_release_checkout).and_yield("/refreshed")
      allow(self).to receive(:validate_release_ci_status!)
      allow(self).to receive(:target_gem_version).and_return("10.4.0")
      allow(self).to receive(:warn_changelog_missing)
      allow(self).to receive(:validate_release_version_policy!)
      allow(self).to receive(:refresh_release_root_lockfile)
      allow(self).to receive(:refresh_spec_dummy_lockfiles)
      allow(self).to receive(:current_gem_version).with("/refreshed").and_return("10.4.0")
      allow(self).to receive(:bump_supplemental_core_dep)
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir)
      allow(self).to receive(:extract_changelog_section).and_return(nil)
      allow(self).to receive(:extract_changelog_section)
        .with(changelog_path: "/refreshed/CHANGELOG.md", npm_version: "10.4.0")
        .and_return("release notes")

      result = perform_release(gem_version: "10.4.0", dry_run: true, check_uncommitted: false)

      expect(result[:changelog_section_found]).to be(true)
    end
  end

  describe "#extract_changelog_section" do
    around do |example|
      Dir.mktmpdir("shakapacker-changelog-encoding-spec") do |tmpdir|
        @changelog_path = File.join(tmpdir, "CHANGELOG.md")
        # Mirrors the real CHANGELOG: non-ASCII lives below the version headers, so only a
        # scan that runs off the end of the file reaches it.
        File.write(@changelog_path, <<~MARKDOWN, encoding: "UTF-8")
          # Versions

          ## [Unreleased]

          ## [v10.3.2] - August 28, 2026

          ### Fixed

          - **Fixed a thing.** [PR #1](https://example.com/1) by [x](https://example.com/x).

          ## [v10.3.1] - August 3, 2026

          ### ⚠️ Breaking Changes

          - **Removed a thing** — see the migration guide.
        MARKDOWN
        example.run
      end
    end

    it "returns the section for a version that is present" do
      section = extract_changelog_section(changelog_path: @changelog_path, npm_version: "10.3.2")

      expect(section).to include("Fixed a thing")
      expect(section).not_to include("Breaking Changes")
    end

    it "returns nil rather than raising when the version has no section and the changelog is not ASCII" do
      # A missing version scans the whole file, so the non-ASCII tail is always reached.
      expect(extract_changelog_section(changelog_path: @changelog_path, npm_version: "99.99.99")).to be_nil
    end

    it "reads the changelog as UTF-8 so a non-UTF-8 default external encoding cannot break matching" do
      # Encoding.default_external is process-global, so assert the read is pinned instead of
      # mutating it. Without the explicit encoding, `LANG`-less environments (CI images, cron,
      # Docker) raise ArgumentError: invalid byte sequence in US-ASCII while scanning.
      allow(File).to receive(:readlines).and_call_original

      extract_changelog_section(changelog_path: @changelog_path, npm_version: "99.99.99")

      expect(File).to have_received(:readlines).with(@changelog_path, encoding: "UTF-8")
    end
  end

  describe "#extract_latest_changelog_version" do
    around do |example|
      Dir.mktmpdir("shakapacker-changelog-version-encoding-spec") do |tmpdir|
        @gem_root = tmpdir
        # Mirrors the real CHANGELOG: non-ASCII below the version headers.
        File.write(File.join(tmpdir, "CHANGELOG.md"), <<~MARKDOWN, encoding: "UTF-8")
          # Versions

          ## [Unreleased]

          ## [v10.3.2] - August 28, 2026

          ### ⚠️ Breaking Changes

          - **Removed a thing** — see the migration guide.
        MARKDOWN
        example.run
      end
    end

    it "reads the changelog as UTF-8 so a non-UTF-8 default external encoding cannot break matching" do
      # Encoding.default_external is process-global, so assert the read is pinned instead of
      # mutating it. Mirrors the sibling guard on #extract_changelog_section — without this,
      # the encoding argument here could be dropped by a future edit with no spec failing.
      allow(File).to receive(:readlines).and_call_original

      expect(extract_latest_changelog_version(gem_root: @gem_root)).to eq("10.3.2")

      expect(File).to have_received(:readlines).with(File.join(@gem_root, "CHANGELOG.md"), encoding: "UTF-8")
    end
  end

  describe "#fetch_gh_jsonl" do
    it "parses stdout without mixing in successful gh diagnostics from stderr" do
      status = double("status", success?: true)
      command = ["gh", "api", "--paginate", "--jq", ".workflow_runs[]", "repos/example/actions/runs"]
      allow(Open3).to receive(:capture3).with(*command).and_return(["{\"id\":1}\n", "gh update available\n", status])

      expect(fetch_gh_jsonl("repos/example/actions/runs", ".workflow_runs[]"))
        .to eq([[{ "id" => 1 }], nil])
    end
  end

  describe "#validate_release_ci_status!" do
    let(:commit_sha) { "abc123" }

    def stub_gh_jsonl(path_fragment, objects, success: true)
      status = double("status", success?: success)
      allow(Open3).to receive(:capture3)
        .with("gh", "api", "--paginate", "--jq", anything, a_string_including(path_fragment))
        .and_return([objects.map(&:to_json).join("\n"), "", status])
    end

    def stub_commit_statuses(rows, success: true)
      objects = rows.map.with_index do |(context, state, created_at), index|
        timestamp = created_at || "2026-01-0#{index + 1}T00:00:00Z"
        {
          id: index + 1,
          node_id: "status-node-#{index + 1}",
          url: "https://api.github.com/repos/shakacode/shakapacker/statuses/#{commit_sha}",
          state: state,
          description: "review status",
          target_url: "https://example.test/status/#{index + 1}",
          context: context,
          created_at: timestamp,
          updated_at: timestamp,
          creator: { login: "review-bot" }
        }
      end
      stub_gh_jsonl("/status", objects, success: success)
    end

    def stub_main_push_workflow_runs(rows, success: true)
      objects = rows.map.with_index do |(name, run_status, conclusion), index|
        {
          id: index + 1,
          name: name,
          event: "push",
          status: run_status,
          conclusion: conclusion,
          head_branch: "main",
          head_sha: commit_sha,
          run_attempt: 1,
          created_at: "2026-08-23T09:30:00Z",
          updated_at: "2026-08-23T09:31:00Z",
          workflow_id: index + 100
        }
      end
      stub_gh_jsonl(
        "actions/runs?head_sha=#{commit_sha}&event=push&branch=main&per_page=100",
        objects,
        success: success
      )
    end

    def successful_main_push_workflow_runs
      [
        ["Dummy specs", "completed", "success"],
        ["Generator specs", "completed", "success"],
        ["Node based checks", "completed", "success"],
        ["Ruby based checks", "completed", "success"],
        ["Test Both Bundlers", "completed", "success"]
      ]
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RELEASE_CI_STATUS_OVERRIDE").and_return(nil)

      origin_status = double("status", success?: true)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/repo", "remote", "get-url", "origin")
        .and_return(["git@github.com:shakacode/shakapacker.git\n", origin_status])

      head_status = double("status", success?: true)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/repo", "rev-parse", "HEAD")
        .and_return(["#{commit_sha}\n", head_status])

      stub_main_push_workflow_runs(successful_main_push_workflow_runs)
      # Most examples exercise workflow runs only; default the statuses endpoint to empty.
      stub_commit_statuses([])
    end

    def validate(allow_override: false, dry_run: false)
      validate_release_ci_status!(gem_root: "/repo", allow_override: allow_override, dry_run: dry_run)
    end

    it "passes when every expected main-push workflow completed successfully" do
      expect do
        expect { validate }.not_to raise_error
      end.to output(/✓ CI is green for #{commit_sha} \(5 main-push workflows, 0 commit-status signals\)/).to_stdout
    end

    it "blocks before the expected main-push workflow suite starts even when supplemental statuses are green" do
      stub_commit_statuses([["CodeRabbit", "success"]])
      stub_main_push_workflow_runs([])

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Missing main-push workflows/).to_stderr
    end

    it "blocks while any expected main-push workflow is still queued" do
      stub_main_push_workflow_runs(
        [
          ["Dummy specs", "completed", "success"],
          ["Generator specs", "queued", nil],
          ["Node based checks", "completed", "success"],
          ["Ruby based checks", "completed", "success"],
          ["Test Both Bundlers", "completed", "success"]
        ]
      )

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Still running.*Generator specs \(queued\)/m).to_stderr
    end

    it "blocks when any expected main-push workflow completed unsuccessfully" do
      stub_main_push_workflow_runs(
        [
          ["Dummy specs", "completed", "success"],
          ["Generator specs", "completed", "success"],
          ["Node based checks", "completed", "success"],
          ["Ruby based checks", "completed", "failure"],
          ["Test Both Bundlers", "completed", "success"]
        ]
      )

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Not passing.*Ruby based checks \(failure\)/m).to_stderr
    end

    it "evaluates only the latest run for each expected main-push workflow" do
      stub_main_push_workflow_runs(
        successful_main_push_workflow_runs +
          [
            ["Generator specs", "completed", "failure"],
            ["Generator specs", "completed", "success"]
          ]
      )

      expect do
        expect { validate }.not_to raise_error
      end.to output(/✓ CI is green for #{commit_sha} \(5 main-push workflows, 0 commit-status signals\)/).to_stdout
    end

    it "does not gate on unrelated conditional push workflows" do
      stub_main_push_workflow_runs(
        successful_main_push_workflow_runs + [["Trigger docs site rebuild", "completed", "failure"]]
      )

      expect do
        expect { validate }.not_to raise_error
      end.to output(/✓ CI is green for #{commit_sha} \(5 main-push workflows, 0 commit-status signals\)/).to_stdout
    end

    it "blocks when a present Babel 8 smoke workflow run fails" do
      stub_main_push_workflow_runs(
        successful_main_push_workflow_runs + [["Babel 8 smoke", "completed", "failure"]]
      )

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Not passing.*Babel 8 smoke \(failure\)/m).to_stderr
    end

    it "blocks while a present Babel 8 smoke workflow run is pending" do
      stub_main_push_workflow_runs(
        successful_main_push_workflow_runs + [["Babel 8 smoke", "queued", nil]]
      )

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Still running.*Babel 8 smoke \(queued\)/m).to_stderr
    end

    it "passes when a present Babel 8 smoke workflow run succeeds" do
      stub_main_push_workflow_runs(
        successful_main_push_workflow_runs + [["Babel 8 smoke", "completed", "success"]]
      )

      expect { validate }
        .to output(/✓ CI is green for #{commit_sha} \(6 main-push workflows, 0 commit-status signals\)/).to_stdout
    end

    it "aborts and names the failing main-push workflow" do
      rows = successful_main_push_workflow_runs.map do |row|
        row.first == "Node based checks" ? ["Node based checks", "completed", "failure"] : row
      end
      stub_main_push_workflow_runs(rows)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/CI is not green.*Not passing \(1\):\n  - Node based checks \(failure\)/m).to_stderr
    end

    it "treats a cancelled main-push workflow as not passing" do
      rows = successful_main_push_workflow_runs.map do |row|
        row.first == "Generator specs" ? ["Generator specs", "completed", "cancelled"] : row
      end
      stub_main_push_workflow_runs(rows)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Not passing \(1\):\n  - Generator specs \(cancelled\)/).to_stderr
    end

    it "requires success rather than a neutral conclusion for every main-push workflow" do
      rows = successful_main_push_workflow_runs.map do |row|
        row.first == "Dummy specs" ? ["Dummy specs", "completed", "neutral"] : row
      end
      stub_main_push_workflow_runs(rows)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Not passing \(1\):\n  - Dummy specs \(neutral\)/).to_stderr
    end

    it "aborts while a main-push workflow is still running" do
      rows = successful_main_push_workflow_runs.map do |row|
        row.first == "Dummy specs" ? ["Dummy specs", "in_progress", nil] : row
      end
      stub_main_push_workflow_runs(rows)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Still running \(1\):\n  - Dummy specs \(in_progress\)/).to_stderr
    end

    it "aborts when the commit has no main-push workflow runs" do
      stub_main_push_workflow_runs([])

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Missing main-push workflows for #{commit_sha}/).to_stderr
    end

    it "fails closed when CI status cannot be read" do
      stub_main_push_workflow_runs([], success: false)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Unable to verify CI status for #{commit_sha}/).to_stderr
    end

    it "fails closed when the GitHub CLI is missing" do
      allow(Open3).to receive(:capture3)
        .with("gh", "api", "--paginate", "--jq", anything, a_string_including("actions/runs"))
        .and_raise(Errno::ENOENT)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/GitHub CLI is not installed/).to_stderr
    end

    it "releases anyway when the override argument is set" do
      stub_main_push_workflow_runs([])

      expect { validate(allow_override: true) }.to output(/CI STATUS OVERRIDE enabled/).to_stdout
    end

    it "releases anyway when RELEASE_CI_STATUS_OVERRIDE is set" do
      allow(ENV).to receive(:[]).with("RELEASE_CI_STATUS_OVERRIDE").and_return("true")
      stub_main_push_workflow_runs([])

      expect { validate(allow_override: ci_status_override_enabled?(nil)) }
        .to output(/CI STATUS OVERRIDE enabled/).to_stdout
    end

    it "reports instead of aborting during a dry run" do
      rows = successful_main_push_workflow_runs.map do |row|
        row.first == "Node based checks" ? ["Node based checks", "completed", "failure"] : row
      end
      stub_main_push_workflow_runs(rows)

      expect { validate(dry_run: true) }
        .to output(/DRY RUN: Release would be blocked.*Node based checks \(failure\)/m).to_stdout
    end

    # Not every integration reports through GitHub Actions. CodeRabbit posts legacy commit
    # statuses, so ignoring that endpoint would let a failing status read as green.
    context "with legacy commit statuses" do
      it "blocks on a failing commit status even when every required workflow passed" do
        stub_commit_statuses([["CodeRabbit", "failure"]])

        expect do
          expect { validate }.to raise_error(SystemExit)
        end.to output(/Not passing \(1\):\n  - CodeRabbit \(failure\)/).to_stderr
      end

      it "blocks while a commit status is still pending" do
        stub_commit_statuses([["CodeRabbit", "pending"]])

        expect do
          expect { validate }.to raise_error(SystemExit)
        end.to output(/Still running \(1\):\n  - CodeRabbit \(pending\)/).to_stderr
      end

      it "counts a successful commit status toward the green total" do
        stub_commit_statuses([["CodeRabbit", "success"]])

        expect { validate }
          .to output(/✓ CI is green for #{commit_sha} \(5 main-push workflows, 1 commit-status signals\)/).to_stdout
      end

      it "uses the latest status per context returned by GitHub's combined-status endpoint" do
        stub_commit_statuses([["CodeRabbit", "success", "2026-01-02T00:00:00Z"]])

        expect { validate }
          .to output(/✓ CI is green for #{commit_sha} \(5 main-push workflows, 1 commit-status signals\)/).to_stdout
      end

      it "blocks on an unknown status state rather than assuming it passed" do
        stub_commit_statuses([["Mystery", "banana"]])

        expect do
          expect { validate }.to raise_error(SystemExit)
        end.to output(/Not passing \(1\):\n  - Mystery \(error\)/).to_stderr
      end
    end
  end
end
