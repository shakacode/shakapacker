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

      def workflow_job(conclusion)
        { status: "completed", conclusion: conclusion }
      end

      def workflow_run(name, conclusion, event: "pull_request", pull_requests: [123], job_pages: nil)
        @workflow_run_id = (@workflow_run_id || 0) + 1
        {
          id: @workflow_run_id,
          name: name,
          status: "completed",
          conclusion: conclusion,
          event: event,
          head_sha: HEAD_SHA,
          pull_requests: pull_requests.map { |number| { number: number } },
          fixture_job_pages: job_pages || [[workflow_job(conclusion)]]
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
    "fork_success_run_with_only_skipped_jobs" => {
      pr: fork_pr(merge_state_status: "UNSTABLE", title: "Fork whose successful run executed no jobs"),
      checks: [
        check("Ruby fork gate", "SKIPPED", "skipping"),
        check("CodeRabbit", "SUCCESS", "pass")
      ],
      check_runs: [
        check_run("Ruby fork gate", "skipped"),
        check_run("CodeRabbit", "success", app: "coderabbit")
      ],
      workflow_runs: [
        workflow_run("Ruby based checks", "success", job_pages: [[workflow_job("skipped")]])
      ],
      threads: []
    },
    "fork_successful_job_on_second_page" => {
      pr: fork_pr(merge_state_status: "UNSTABLE", title: "Fork whose successful job is on page two"),
      checks: [
        check("Ruby fork gate", "SKIPPED", "skipping"),
        check("CodeRabbit", "SUCCESS", "pass")
      ],
      check_runs: [
        check_run("Ruby fork gate", "skipped"),
        check_run("CodeRabbit", "success", app: "coderabbit")
      ],
      workflow_runs: [
        workflow_run(
          "Ruby based checks",
          "success",
          job_pages: [Array.new(100) { workflow_job("skipped") }, [workflow_job("success")]]
        )
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
    "fork_other_pr_success_only" => {
      pr: fork_pr(merge_state_status: "CLEAN", title: "Fork whose successful run belongs to another PR"),
      checks: [check("Ruby specs", "SUCCESS", "pass")],
      check_runs: [check_run("Ruby specs", "success")],
      workflow_runs: [workflow_run("Ruby based checks", "success", pull_requests: [999])],
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
    "fork_current_ci_with_other_pr_action_required" => {
      pr: fork_pr(merge_state_status: "CLEAN", title: "Fork with another PR awaiting workflow approval"),
      checks: [check("Ruby specs", "SUCCESS", "pass")],
      check_runs: [check_run("Ruby specs", "success")],
      workflow_runs: [
        workflow_run("Ruby based checks", "success"),
        workflow_run("Other PR checks", "action_required", pull_requests: [999])
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
      workflow_runs: [
        workflow_run("Ruby based checks", "success"),
        workflow_run("Ruby based checks", "action_required")
      ],
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
    },
    "merged_fork_without_run_association" => {
      pr: fork_pr.merge(
        title: "Merged fork whose workflow association expired",
        state: "MERGED",
        mergeStateStatus: "UNKNOWN",
        mergedAt: "2026-08-01T13:00:00Z",
        reviewDecision: "REVIEW_REQUIRED"
      ),
      checks: [check("Ruby specs", "SUCCESS", "pass")],
      check_runs: [check_run("Ruby specs", "success")],
      workflow_runs: [workflow_run("Ruby based checks", "success", pull_requests: [])],
      threads: []
    },
    "merged_fork_with_foreign_success" => {
      pr: fork_pr.merge(
        title: "Merged fork whose successful run belongs to another PR",
        state: "MERGED",
        mergeStateStatus: "UNKNOWN",
        mergedAt: "2026-08-01T13:00:00Z",
        reviewDecision: "REVIEW_REQUIRED"
      ),
      checks: [check("Ruby specs", "SUCCESS", "pass")],
      check_runs: [check_run("Ruby specs", "success")],
      workflow_runs: [workflow_run("Other PR checks", "success", pull_requests: [999])],
      threads: []
    },
    "merged_fork_with_foreign_approval" => {
      pr: fork_pr.merge(
        title: "Merged fork whose approval-pending run belongs to another PR",
        state: "MERGED",
        mergeStateStatus: "UNKNOWN",
        mergedAt: "2026-08-01T13:00:00Z",
        reviewDecision: "REVIEW_REQUIRED"
      ),
      checks: [check("Ruby specs", "SUCCESS", "pass")],
      check_runs: [check_run("Ruby specs", "success")],
      workflow_runs: [
        workflow_run("Ruby based checks", "success", pull_requests: []),
        workflow_run("Other PR checks", "action_required", pull_requests: [999])
      ],
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

  def test_successful_workflow_with_only_skipped_jobs_is_not_ready
    assert_not_ready("fork_success_run_with_only_skipped_jobs", "fork CI has not started")
  end

  def test_successful_job_on_second_page_proves_fork_ci_started
    result = run_scenario("fork_successful_job_on_second_page")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  def test_unapproved_current_pull_request_workflow_is_not_ready
    result = run_scenario("fork_unapproved")

    assert_equal 1, result[:status]
    assert_includes result[:stderr], "MERGE_READINESS_NOT_READY"
    assert_includes result[:stderr], "1 workflow run(s) require approval"
  end

  def test_intentional_skipped_fork_gate_still_requires_review
    assert_not_ready("fork_skipped_review_required", "reviewDecision is REVIEW_REQUIRED")
  end

  def test_auxiliary_workflow_success_does_not_prove_fork_ci_started
    assert_not_ready("fork_auxiliary_success_only", "fork CI has not started")
  end

  def test_successful_workflow_for_another_pr_does_not_prove_fork_ci_started
    assert_not_ready("fork_other_pr_success_only", "fork CI has not started")
  end

  def test_auxiliary_workflow_approval_does_not_block_real_fork_ci
    result = run_scenario("fork_real_ci_with_auxiliary_action_required")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  def test_workflow_approval_for_another_pr_does_not_block_current_fork_ci
    result = run_scenario("fork_current_ci_with_other_pr_action_required")

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

  def test_merged_fork_replay_accepts_exact_head_run_without_current_association
    result = run_scenario("merged_fork_without_run_association")

    assert_equal 0, result[:status], result[:stderr]
    assert_includes result[:stdout], "MERGE_READINESS_READY"
  end

  def test_merged_fork_replay_rejects_success_associated_with_another_pull_request
    assert_not_ready("merged_fork_with_foreign_success", "no successful pull_request workflow-run evidence")
  end

  def test_merged_fork_replay_ignores_approval_pending_run_for_another_pull_request
    result = run_scenario("merged_fork_with_foreign_approval")

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
        expected_fields = %w[page per_page]
        expected_fields << "head_sha" if expected_head_sha
        unless fields.keys.sort == expected_fields.sort
          abort "Unexpected GitHub API query fields: \#{args.inspect}"
        end

        page = Integer(fields.fetch("page"), 10)
        abort "Expected a 1-based page: \#{args.inspect}" unless page.positive?

        page
      rescue ArgumentError, KeyError
        abort "Expected an integer page: \#{args.inspect}"
      end

      def api_collection(fixture, item_key, pages_key, page)
        pages = fixture[pages_key] || [fixture.fetch(item_key)]
        collection_page(item_key, pages, page)
      end

      def collection_page(item_key, pages, page)
        items = pages.fetch(page - 1, [])
        if item_key == "workflow_runs"
          items = items.map { |item| item.reject { |key, _value| key.start_with?("fixture_") } }
        end
        {
          "total_count" => pages.sum(&:length),
          item_key => items
        }
      end

      jobs_endpoint = args.find do |arg|
        arg.match?(%r{\\Arepos/shakacode/shakapacker/actions/runs/\\d+/jobs\\z})
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
               elsif jobs_endpoint
                 run_id = Integer(jobs_endpoint.split("/").fetch(-2), 10)
                 workflow_runs = fixture["workflow_runs"] || fixture.fetch("workflow_run_pages").flatten
                 workflow_run = workflow_runs.find { |run| run.fetch("id") == run_id }
                 abort "Unexpected workflow run id: \#{run_id}" unless workflow_run

                 page = api_page(args, jobs_endpoint)
                 collection_page("jobs", workflow_run.fetch("fixture_job_pages"), page)
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
