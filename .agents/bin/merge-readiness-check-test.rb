#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "tmpdir"

class MergeReadinessCheckTest < Minitest::Test
  SCRIPT = File.expand_path("merge-readiness-check", __dir__)
  HEAD_SHA = "1" * 40

  class << self
    private

      def check(name, state, bucket)
        {
          name: name,
          state: state,
          bucket: bucket,
          completedAt: "2026-08-01T12:00:00Z",
          startedAt: "2026-08-01T11:00:00Z",
          workflow: "Fixture workflow",
          link: "https://github.com/shakacode/shakapacker/actions/runs/1"
        }
      end

      def check_run(name, conclusion, app: "github-actions")
        {
          name: name,
          status: "completed",
          conclusion: conclusion,
          app: { slug: app }
        }
      end

      def workflow_run(name, conclusion, event: "pull_request")
        {
          name: name,
          status: "completed",
          conclusion: conclusion,
          event: event,
          head_sha: HEAD_SHA
        }
      end

      def fork_pr(merge_state_status: "CLEAN", title: "Fork PR")
        same_repo_pr.merge(
          title: title,
          isCrossRepository: true,
          mergeStateStatus: merge_state_status
        )
      end

      def same_repo_pr(merge_state_status: "CLEAN")
        {
          number: 123,
          title: "Same-repository PR",
          state: "OPEN",
          isDraft: false,
          isCrossRepository: false,
          headRefOid: HEAD_SHA,
          mergeStateStatus: merge_state_status,
          mergedAt: nil,
          url: "https://github.com/shakacode/shakapacker/pull/123",
          reviewDecision: "APPROVED"
        }
      end
  end

  FIXTURES = {
    "fork_skipped_ready" => {
      pr: {
        number: 123,
        title: "Fork with an intentional skipped gate",
        state: "OPEN",
        isDraft: false,
        isCrossRepository: true,
        headRefOid: HEAD_SHA,
        mergeStateStatus: "UNSTABLE",
        mergedAt: nil,
        url: "https://github.com/shakacode/shakapacker/pull/123",
        reviewDecision: "APPROVED"
      },
      checks: [
        check("Ruby specs", "SUCCESS", "pass"),
        check("claude-review", "SKIPPED", "skipping")
      ],
      check_runs: [
        check_run("Ruby specs", "success"),
        check_run("claude-review", "skipped")
      ],
      workflow_runs: [
        workflow_run("Ruby based checks", "success"),
        workflow_run("Claude Code Review", "skipped")
      ],
      threads: []
    },
    "fork_skipped_review_required" => {
      pr: {
        number: 123,
        title: "Fork with an intentional skipped gate awaiting review",
        state: "OPEN",
        isDraft: false,
        isCrossRepository: true,
        headRefOid: HEAD_SHA,
        mergeStateStatus: "UNSTABLE",
        mergedAt: nil,
        url: "https://github.com/shakacode/shakapacker/pull/123",
        reviewDecision: "REVIEW_REQUIRED"
      },
      checks: [
        check("Ruby specs", "SUCCESS", "pass"),
        check("claude-review", "SKIPPED", "skipping")
      ],
      check_runs: [
        check_run("Ruby specs", "success"),
        check_run("claude-review", "skipped")
      ],
      workflow_runs: [
        workflow_run("Ruby based checks", "success"),
        workflow_run("Claude Code Review", "skipped")
      ],
      threads: []
    },
    "fork_auxiliary_success_only" => {
      pr: fork_pr(merge_state_status: "UNSTABLE", title: "Fork with only auxiliary workflow success"),
      checks: [
        check("Comment helper", "SUCCESS", "pass"),
        check("claude-review", "SKIPPED", "skipping")
      ],
      check_runs: [
        check_run("Comment helper", "success"),
        check_run("claude-review", "skipped")
      ],
      workflow_runs: [
        workflow_run("Comment helper", "success", event: "pull_request_review_comment"),
        workflow_run("Claude Code Review", "skipped")
      ],
      threads: []
    },
    "fork_real_ci_with_auxiliary_action_required" => {
      pr: fork_pr(merge_state_status: "UNSTABLE", title: "Fork with real CI and auxiliary approval pending"),
      checks: [
        check("Ruby specs", "SUCCESS", "pass"),
        check("claude-review", "SKIPPED", "skipping")
      ],
      check_runs: [
        check_run("Ruby specs", "success"),
        check_run("claude-review", "skipped")
      ],
      workflow_runs: [
        workflow_run("Ruby based checks", "success"),
        workflow_run("Comment helper", "action_required", event: "pull_request_review_comment"),
        workflow_run("Claude Code Review", "skipped")
      ],
      threads: []
    },
    "fork_paginated_evidence" => {
      pr: fork_pr(merge_state_status: "UNSTABLE", title: "Fork with evidence on second API pages"),
      checks: [
        check("Ruby specs", "SUCCESS", "pass"),
        check("claude-review", "SKIPPED", "skipping")
      ],
      check_run_pages: [
        Array.new(100) { |index| check_run("External check #{index}", "success", app: "external-reviewer") },
        [check_run("claude-review", "skipped")]
      ],
      workflow_run_pages: [
        Array.new(100) do |index|
          workflow_run("Comment helper #{index}", "success", event: "pull_request_review_comment")
        end,
        [workflow_run("Ruby based checks", "success")]
      ],
      threads: []
    },
    "fork_unapproved" => {
      pr: fork_pr(merge_state_status: "CLEAN", title: "Fork awaiting workflow approval"),
      checks: [check("CodeRabbit", "SUCCESS", "pass")],
      check_runs: [],
      workflow_runs: [workflow_run("Ruby based checks", "action_required")],
      threads: []
    },
    "fork_only_skipped" => {
      pr: fork_pr(merge_state_status: "UNSTABLE", title: "Fork without passing CI"),
      checks: [
        check("claude-review", "SKIPPED", "skipping"),
        check("CodeRabbit", "SUCCESS", "pass")
      ],
      check_runs: [check_run("claude-review", "skipped")],
      workflow_runs: [workflow_run("Claude Code Review", "skipped")],
      threads: []
    },
    "same_repo_unstable" => {
      pr: same_repo_pr(merge_state_status: "UNSTABLE"),
      checks: [
        check("Ruby specs", "SUCCESS", "pass"),
        check("optional-review", "SKIPPED", "skipping")
      ],
      check_runs: [
        check_run("Ruby specs", "success"),
        check_run("optional-review", "skipped")
      ],
      workflow_runs: [workflow_run("Ruby based checks", "success")],
      threads: []
    },
    "third_party_skipped" => {
      pr: fork_pr(merge_state_status: "UNSTABLE"),
      checks: [
        check("Ruby specs", "SUCCESS", "pass"),
        check("external-review", "SKIPPED", "skipping")
      ],
      check_runs: [
        check_run("Ruby specs", "success"),
        check_run("external-review", "skipped", app: "external-reviewer")
      ],
      workflow_runs: [workflow_run("Ruby based checks", "success")],
      threads: []
    },
    "fork_clean_third_party_skipped" => {
      pr: fork_pr(merge_state_status: "CLEAN", title: "Fork with a legitimate skipped third-party reviewer"),
      checks: [
        check("Ruby specs", "SUCCESS", "pass"),
        check("external-review", "SKIPPED", "skipping")
      ],
      check_runs: [
        check_run("Ruby specs", "success"),
        check_run("external-review", "skipped", app: "external-reviewer")
      ],
      workflow_runs: [workflow_run("Ruby based checks", "success")],
      threads: []
    },
    "failing_check" => {
      pr: same_repo_pr,
      checks: [check("Ruby specs", "FAILURE", "fail")],
      check_runs: [check_run("Ruby specs", "failure")],
      workflow_runs: [workflow_run("Ruby based checks", "failure")],
      threads: []
    },
    "unresolved_thread" => {
      pr: same_repo_pr,
      checks: [check("Ruby specs", "SUCCESS", "pass")],
      check_runs: [check_run("Ruby specs", "success")],
      workflow_runs: [workflow_run("Ruby based checks", "success")],
      threads: [{ id: "thread-1", isResolved: false }]
    },
    "merged_review_required" => {
      pr: same_repo_pr.merge(
        title: "Merged PR whose current review decision drifted",
        state: "MERGED",
        mergeStateStatus: "UNKNOWN",
        mergedAt: "2026-08-01T13:00:00Z",
        reviewDecision: "REVIEW_REQUIRED"
      ),
      checks: [check("Ruby specs", "SUCCESS", "pass")],
      check_runs: [check_run("Ruby specs", "success")],
      workflow_runs: [workflow_run("Ruby based checks", "success")],
      threads: []
    }
  }.freeze

  def setup
    @tmpdir = Dir.mktmpdir("merge-readiness-check-test")
    fake_gh = File.join(@tmpdir, "gh")
    File.write(fake_gh, fake_gh_source)
    FileUtils.chmod(0o755, fake_gh)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_intentional_skipped_fork_gate_can_be_ready
    result = run_scenario("fork_skipped_ready")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  def test_unapproved_fork_without_actions_check_evidence_is_not_ready
    result = run_scenario("fork_unapproved")

    assert_equal 1, result[:status]
    assert_includes result[:stderr], "MERGE_READINESS_NOT_READY"
    assert_includes result[:stderr], "fork CI has not started"
  end

  def test_intentional_skipped_fork_gate_still_requires_review
    assert_not_ready("fork_skipped_review_required", "reviewDecision is REVIEW_REQUIRED")
  end

  def test_auxiliary_workflow_success_does_not_prove_fork_ci_started
    assert_not_ready("fork_auxiliary_success_only", "fork CI has not started")
  end

  def test_auxiliary_workflow_approval_does_not_block_real_fork_ci
    result = run_scenario("fork_real_ci_with_auxiliary_action_required")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  def test_second_api_pages_are_requested_and_combined
    result = run_scenario("fork_paginated_evidence")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  def test_fork_with_only_a_skipped_actions_gate_is_not_ready
    assert_not_ready("fork_only_skipped", "no successful pull_request workflow-run evidence")
  end

  def test_same_repository_unstable_state_remains_blocking
    assert_not_ready("same_repo_unstable", "mergeStateStatus is UNSTABLE")
  end

  def test_third_party_skipped_check_cannot_explain_fork_instability
    assert_not_ready("third_party_skipped", "mergeStateStatus is UNSTABLE")
  end

  def test_clean_fork_with_legitimate_skipped_third_party_reviewer_can_be_ready
    result = run_scenario("fork_clean_third_party_skipped")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  def test_failing_check_remains_blocking
    assert_not_ready("failing_check", "1 check(s) are not pass/skipped")
  end

  def test_unresolved_review_thread_remains_blocking
    assert_not_ready("unresolved_thread", "1 unresolved review thread(s) remain")
  end

  def test_merged_replay_ignores_current_review_required_decision
    result = run_scenario("merged_review_required")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  private

    def assert_not_ready(scenario, message)
      result = run_scenario(scenario)

      assert_equal 1, result[:status]
      assert_includes result[:stderr], "MERGE_READINESS_NOT_READY"
      assert_includes result[:stderr], message
    end

    def run_scenario(scenario)
      stdout, stderr, status = Open3.capture3(
        {
          "PATH" => "#{@tmpdir}:#{ENV.fetch('PATH')}",
          "MERGE_READINESS_SCENARIO" => scenario
        },
        SCRIPT, "123", "--repo", "shakacode/shakapacker"
      )

      { stdout: stdout, stderr: stderr, status: status.exitstatus }
    end

    def fake_gh_source
      <<~RUBY
      #!/usr/bin/env ruby
      # frozen_string_literal: true

      require "json"

      fixtures = JSON.parse(#{JSON.generate(FIXTURES).inspect})
      fixture = fixtures.fetch(ENV.fetch("MERGE_READINESS_SCENARIO"))
      args = ARGV

      def api_page(args, expected_endpoint, expected_head_sha: nil)
        unless args.each_cons(2).any? { |flag, value| flag == "--method" && value == "GET" }
          abort "Expected GitHub API request to use GET: \#{args.inspect}"
        end
        abort "Unexpected GitHub API endpoint: \#{args.inspect}" unless args.include?(expected_endpoint)

        fields = args.each_index.each_with_object({}) do |index, values|
          next unless args[index] == "-f"

          key, value = args.fetch(index + 1).split("=", 2)
          values[key] = value
        end
        abort "Expected per_page=100: \#{args.inspect}" unless fields["per_page"] == "100"
        if expected_head_sha && fields["head_sha"] != expected_head_sha
          abort "Expected head_sha=\#{expected_head_sha}: \#{args.inspect}"
        end

        page = Integer(fields.fetch("page"), 10)
        abort "Expected a 1-based page: \#{args.inspect}" unless page.positive?

        page
      rescue ArgumentError, KeyError
        abort "Expected an integer page: \#{args.inspect}"
      end

      def api_collection(fixture, item_key, pages_key, page)
        pages = fixture[pages_key] || [fixture.fetch(item_key)]
        {
          "total_count" => pages.sum(&:length),
          item_key => pages.fetch(page - 1, [])
        }
      end

      output = if args[0, 2] == ["pr", "view"]
                 fixture.fetch("pr")
               elsif args[0, 2] == ["pr", "checks"]
                 fixture.fetch("checks")
               elsif args.include?("graphql")
                 {
                   data: {
                     repository: {
                       pullRequest: {
                         reviewThreads: {
                           nodes: fixture.fetch("threads"),
                           pageInfo: { hasNextPage: false, endCursor: nil }
                         }
                       }
                     }
                   }
                 }
               elsif args.any? { |arg| arg.include?("/check-runs") }
                 head_sha = fixture.fetch("pr").fetch("headRefOid")
                 endpoint = "repos/shakacode/shakapacker/commits/\#{head_sha}/check-runs"
                 page = api_page(args, endpoint)
                 api_collection(fixture, "check_runs", "check_run_pages", page)
               elsif args.any? { |arg| arg.include?("/actions/runs") }
                 head_sha = fixture.fetch("pr").fetch("headRefOid")
                 endpoint = "repos/shakacode/shakapacker/actions/runs"
                 page = api_page(args, endpoint, expected_head_sha: head_sha)
                 api_collection(fixture, "workflow_runs", "workflow_run_pages", page)
               else
                 warn "Unexpected gh invocation: \#{args.inspect}"
                 exit 2
               end

      puts JSON.generate(output)
    RUBY
    end
end
