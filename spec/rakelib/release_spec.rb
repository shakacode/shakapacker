require "spec_helper"
require "rake"

load File.expand_path("../../rakelib/release.rake", __dir__)

RSpec.describe "release rake helpers" do
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
      end

      expect do
        expect do
          with_release_checkout(gem_root: "/repo", dry_run: true) { "ok" }
        end.to raise_error(RuntimeError, "cleanup failed")
      end.to output(/Failed to remove dry-run release worktree/).to_stderr
    end
  end
end
