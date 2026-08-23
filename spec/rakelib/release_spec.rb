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
      end.not_to output(/GITHUB_REPO_SLUG_PATTERN|AbortingMessageHandler/).to_stderr
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
    before do
      allow(Dir).to receive(:mktmpdir)
        .with("shakapacker-release-dry-run")
        .and_yield("/tmp/shakapacker-release")
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
      end.to output(/Failed to remove dry-run release worktree/).to_stderr
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
      end.to output(/Failed to remove dry-run release worktree/).to_stderr
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
      end.to output(/Failed to remove dry-run release worktree/).to_stderr
    end
  end
end
