require "spec_helper"
require "rake"
require "shakapacker/configuration"

RSpec.describe "shakapacker:install task" do
  let(:task_name) { "shakapacker:install" }
  let(:task_path) { File.expand_path("../../lib/tasks/shakapacker/install.rake", __dir__) }

  around do |example|
    original_application = Rake.application
    original_bundle_bin = ENV["BUNDLE_BIN"]
    original_assets_bundler = ENV["SHAKAPACKER_ASSETS_BUNDLER"]

    Rake.application = Rake::Application.new
    # install.rake reads Rails.root only when BUNDLE_BIN is unset; set it so the
    # task file loads without a Rails app present.
    ENV["BUNDLE_BIN"] = "/nonexistent/bin"
    # Stub the :check_node prerequisite so the task graph resolves without Node.
    Rake::Task.define_task("shakapacker:check_node")
    load task_path

    example.run
  ensure
    Rake.application = original_application
    Shakapacker::Configuration.installing = false
    ENV["BUNDLE_BIN"] = original_bundle_bin
    if original_assets_bundler.nil?
      ENV.delete("SHAKAPACKER_ASSETS_BUNDLER")
    else
      ENV["SHAKAPACKER_ASSETS_BUNDLER"] = original_assets_bundler
    end
  end

  def invoke_ignoring_exit(*args)
    Rake::Task[task_name].invoke(*args)
  rescue SystemExit
    nil
  end

  context "when given an unknown bundler argument" do
    it "aborts (exits non-zero) before running the install template" do
      # Capture stderr so abort's message doesn't leak into the suite output;
      # the message content itself is asserted in the next example.
      expect do
        expect { Rake::Task[task_name].invoke("wbpack") }.to raise_error(SystemExit)
      end.to output.to_stderr
    end

    it "prints the unknown-bundler error to stderr" do
      expect { invoke_ignoring_exit("wbpack") }.to output(/Unknown bundler 'wbpack'/).to_stderr
    end

    it "does not leave SHAKAPACKER_ASSETS_BUNDLER set to the bad value" do
      ENV.delete("SHAKAPACKER_ASSETS_BUNDLER")
      # Capture stderr so abort's message doesn't leak into the suite output.
      expect { invoke_ignoring_exit("wbpack") }.to output.to_stderr
      expect(ENV).not_to have_key("SHAKAPACKER_ASSETS_BUNDLER")
    end
  end
end
