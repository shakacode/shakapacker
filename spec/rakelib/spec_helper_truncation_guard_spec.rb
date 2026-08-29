require "spec_helper"
require "open3"
require "tmpdir"

# The guards in spec/spec_helper.rb are the reason a truncated run cannot report as a passing one.
# They act on the process, not on an example, so the only way to exercise them is from a child
# process. Without these specs a future edit could quietly disable them and nothing would notice —
# which is exactly the class of silent failure they exist to prevent.
#
# Lives under spec/rakelib/ so the Rakefile's `spec/rakelib/*_spec.rb` glob picks it up; the
# top-level spec/ directory is not covered by any glob in `run_spec:gem`, so a file there would
# never run in CI. The abort-heavy helpers in rakelib/release.rake are what motivated the guards.
RSpec.describe "spec_helper truncation guards" do
  REPO_ROOT = File.expand_path("../..", __dir__)

  around do |example|
    Dir.mktmpdir("shakapacker-truncation-guard") do |dir|
      @probe_dir = dir
      example.run
    end
  end

  # Deliberately not named `*_spec.rb`: a normal suite run must never pick these up. RSpec runs a
  # file passed explicitly regardless of the default pattern.
  def run_probe(body)
    path = File.join(@probe_dir, "truncation_probe.rb")
    File.write(path, body)
    output, status = Open3.capture2e("bundle", "exec", "rspec", path, chdir: REPO_ROOT)
    [output, status]
  end

  it "leaves an ordinary passing run alone" do
    output, status = run_probe(<<~RUBY)
      RSpec.describe("probe") { it("passes") { expect(1).to eq(1) } }
    RUBY

    expect(status).to be_success
    expect(output).to include("1 example, 0 failures")
    expect(output).not_to include("terminated before the suite finished")
  end

  it "turns a SystemExit inside an example into a failure and keeps running the suite" do
    output, status = run_probe(<<~RUBY)
      RSpec.describe("probe") do
        it("exits with a status that would otherwise be green") { exit 0 }
        it("still runs afterwards") { expect(1).to eq(1) }
      end
    RUBY

    expect(status).not_to be_success
    # Both examples reported: the run was not cut short at the exit.
    expect(output).to include("2 examples, 1 failure")
    expect(output).to include("Example exited the process with SystemExit")
  end

  it "fails a run truncated while loading a spec file" do
    output, status = run_probe(<<~RUBY)
      exit 0
      RSpec.describe("probe") { it("never gets defined") { raise "unreachable" } }
    RUBY

    expect(status).not_to be_success
    expect(output).to include("terminated before the suite finished")
  end

  # `after(:suite)` runs from an `ensure` inside `with_suite_hooks`, so the completion flag alone
  # is set even here. This is the case the loaded-versus-started comparison exists for.
  it "fails a run truncated by a before(:suite) hook" do
    output, status = run_probe(<<~RUBY)
      RSpec.configure { |config| config.before(:suite) { exit 0 } }
      RSpec.describe("probe") { it("never runs") { raise "unreachable" } }
    RUBY

    expect(status).not_to be_success
    expect(output).to include("terminated before the suite finished")
  end
end
