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

      def workflow_run(name, conclusion)
        {
          name: name,
          status: "completed",
          conclusion: conclusion,
          event: "pull_request",
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

  def test_fork_with_only_a_skipped_actions_gate_is_not_ready
    assert_not_ready("fork_only_skipped", "no passing GitHub Actions check-run evidence")
  end

  def test_same_repository_unstable_state_remains_blocking
    assert_not_ready("same_repo_unstable", "mergeStateStatus is UNSTABLE")
  end

  def test_third_party_skipped_check_cannot_explain_fork_instability
    assert_not_ready("third_party_skipped", "mergeStateStatus is UNSTABLE")
  end

  def test_failing_check_remains_blocking
    assert_not_ready("failing_check", "1 check(s) are not pass/skipped")
  end

  def test_unresolved_review_thread_remains_blocking
    assert_not_ready("unresolved_thread", "1 unresolved review thread(s) remain")
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
                 runs = fixture.fetch("check_runs")
                 { total_count: runs.length, check_runs: runs }
               elsif args.any? { |arg| arg.include?("/actions/runs") }
                 runs = fixture.fetch("workflow_runs")
                 { total_count: runs.length, workflow_runs: runs }
               else
                 warn "Unexpected gh invocation: \#{args.inspect}"
                 exit 2
               end

      puts JSON.generate(output)
    RUBY
    end
end
