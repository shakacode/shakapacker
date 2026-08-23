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

    it "refreshes the detached dry-run worktree from origin/main before evaluating the release" do
      commands = []
      allow(Shakapacker::Utils::Misc).to receive(:sh_in_dir) do |dir, command|
        commands << [dir, command]
      end

      yielded_root = nil
      with_release_checkout(gem_root: "/repo", dry_run: true) { |release_root| yielded_root = release_root }

      expect(yielded_root).to eq("/tmp/shakapacker-release/worktree")
      expect(commands).to eq(
        [
          ["/repo", "git worktree add --detach /tmp/shakapacker-release/worktree HEAD"],
          ["/tmp/shakapacker-release/worktree", "git fetch origin main"],
          ["/tmp/shakapacker-release/worktree", "git rebase origin/main"],
          ["/repo", "git worktree remove --force /tmp/shakapacker-release/worktree"]
        ]
      )
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

    def stub_gh_jsonl(path_fragment, objects, success: true)
      status = double("status", success?: success)
      allow(Open3).to receive(:capture2e)
        .with("gh", "api", "--paginate", "--jq", anything, a_string_including(path_fragment))
        .and_return([objects.map(&:to_json).join("\n"), status])
    end

    # PR check runs are stubbed only in regression examples proving they cannot satisfy the main-push gate.
    def stub_check_runs(rows, success: true)
      objects = rows.map { |name, run_status, conclusion| { name: name, status: run_status, conclusion: conclusion } }
      stub_gh_jsonl("check-runs", objects, success: success)
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

    it "blocks when successful PR checks exist before the expected main-push workflow suite starts" do
      stub_check_runs([["Ruby based checks", "completed", "success"]])
      stub_commit_statuses([["CodeRabbit", "success"]])
      stub_main_push_workflow_runs([])

      expect do
        expect { validate }.to raise_error(SystemExit)
      end.to output(/Missing main-push workflows/).to_stderr
    end

    it "blocks while any expected main-push workflow is still queued" do
      stub_check_runs([["Ruby PR checks", "completed", "success"]])
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
      stub_check_runs([["Ruby PR checks", "completed", "success"]])
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

    it "ignores failed PR check runs once the expected main-push workflow suite is green" do
      stub_check_runs([["PR Linting", "completed", "failure"]])

      expect { validate }
        .to output(/✓ CI is green for #{commit_sha} \(5 main-push workflows, 0 commit-status signals\)/).to_stdout
    end

    it "does not gate on unrelated conditional push workflows" do
      stub_main_push_workflow_runs(
        successful_main_push_workflow_runs + [["Trigger docs site rebuild", "completed", "failure"]]
      )

      expect do
        expect { validate }.not_to raise_error
      end.to output(/✓ CI is green for #{commit_sha} \(5 main-push workflows, 0 commit-status signals\)/).to_stdout
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
      allow(Open3).to receive(:capture2e)
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
