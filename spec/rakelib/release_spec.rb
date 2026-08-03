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
      end.not_to output(/GITHUB_REPO_SLUG_PATTERN|CI_PASSING_CONCLUSIONS|AbortingMessageHandler/).to_stderr
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

  describe "#validate_release_ci_status!" do
    let(:commit_sha) { "abc123" }

    def stub_check_runs(rows, success: true)
      status = double("status", success?: success)
      allow(Open3).to receive(:capture2e)
        .with("gh", "api", a_string_including("commits/#{commit_sha}/check-runs"), "--paginate", "--jq", anything)
        .and_return([rows.map { |row| row.join("\t") }.join("\n"), status])
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("RELEASE_CI_POLICY_OVERRIDE").and_return(nil)

      origin_status = double("status", success?: true)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/repo", "remote", "get-url", "origin")
        .and_return(["git@github.com:shakacode/shakapacker.git\n", origin_status])

      head_status = double("status", success?: true)
      allow(Open3).to receive(:capture2e)
        .with("git", "-C", "/repo", "rev-parse", "HEAD")
        .and_return(["#{commit_sha}\n", head_status])
    end

    def validate(allow_override: false, dry_run: false)
      validate_release_ci_status!(gem_root: "/repo", allow_override: allow_override, dry_run: dry_run)
    end

    it "passes when every check run completed successfully" do
      stub_check_runs([["Ruby based checks", "completed", "success"], ["claude", "completed", "skipped"]])

      expect { validate }.to output(/✓ CI is green for #{commit_sha} \(2 checks\)/).to_stdout
    end

    it "aborts and names the failing checks" do
      stub_check_runs([["Ruby based checks", "completed", "success"], ["Linting", "completed", "failure"]])

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/CI is not green.*Not passing \(1\):\n  - Linting \(failure\)/m).to_stderr
    end

    it "treats a cancelled check as not passing" do
      stub_check_runs([["Generator specs", "completed", "cancelled"]])

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Not passing \(1\):\n  - Generator specs \(cancelled\)/).to_stderr
    end

    it "aborts while checks are still running" do
      stub_check_runs([["Dummy specs", "in_progress", ""]])

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Still running \(1\):\n  - Dummy specs \(in_progress\)/).to_stderr
    end

    it "aborts when the commit has no CI results at all" do
      stub_check_runs([])

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/No CI results found for #{commit_sha}/).to_stderr
    end

    it "fails closed when CI status cannot be read" do
      stub_check_runs([["irrelevant", "completed", "success"]], success: false)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Unable to verify CI status for #{commit_sha}/).to_stderr
    end

    it "fails closed when the GitHub CLI is missing" do
      allow(Open3).to receive(:capture2e)
        .with("gh", "api", a_string_including("check-runs"), "--paginate", "--jq", anything)
        .and_raise(Errno::ENOENT)

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/GitHub CLI is not installed/).to_stderr
    end

    it "releases anyway when the override argument is set" do
      stub_check_runs([["Linting", "completed", "failure"]])

      expect { validate(allow_override: true) }.to output(/CI POLICY OVERRIDE enabled/).to_stdout
    end

    it "releases anyway when RELEASE_CI_POLICY_OVERRIDE is set" do
      allow(ENV).to receive(:[]).with("RELEASE_CI_POLICY_OVERRIDE").and_return("true")
      stub_check_runs([["Linting", "completed", "failure"]])

      expect { validate(allow_override: ci_policy_override_enabled?(nil)) }
        .to output(/CI POLICY OVERRIDE enabled/).to_stdout
    end

    it "reports instead of aborting during a dry run" do
      stub_check_runs([["Linting", "completed", "failure"]])

      expect { validate(dry_run: true) }.to output(/DRY RUN: Release would be blocked.*Linting \(failure\)/m).to_stdout
    end
  end
end
