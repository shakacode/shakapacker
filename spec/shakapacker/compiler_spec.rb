require_relative "spec_helper_initializer"
require "ostruct"

describe "Shakapacker::Compiler" do
  it "accepts custom environment variables" do
    expect(Shakapacker.compiler.send(:webpack_env)["FOO"]).to be nil

    Shakapacker.compiler.env["FOO"] = "BAR"
    expect(Shakapacker.compiler.send(:webpack_env)["FOO"]).to eq "BAR"
  ensure
    Shakapacker.compiler.env = {}
  end

  it "returns true when fresh" do
    mocked_strategy = double("Strategy")
    expect(mocked_strategy).to receive(:stale?).and_return(false)

    expect(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    expect(Shakapacker.compiler.compile).to be true
  end

  it "returns true and calls after_compile_hook on successful compile" do
    mocked_strategy = spy("Strategy")
    expect(mocked_strategy).to receive(:stale?).and_return(true)

    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    status = OpenStruct.new(success?: true)
    allow(Open3).to receive(:capture3).and_return([:stderr, :stdout, status])

    expect(Shakapacker.compiler.compile).to be true
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "returns false and calls after_compile_hook on failed compile" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(mocked_strategy).to receive(:after_compile_hook)

    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    status = OpenStruct.new(success?: false)
    allow(Open3).to receive(:capture3).and_return([:stderr, :stdout, status])

    expect(Shakapacker.compiler.compile).to be false
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "accepts external env variables" do
    expect(Shakapacker.compiler.send(:webpack_env)["SHAKAPACKER_ASSET_HOST"]).to be nil

    allow(ENV).to receive(:fetch).with("SHAKAPACKER_ASSET_HOST", nil).and_return("foo.bar")

    expect(Shakapacker.compiler.send(:webpack_env)["SHAKAPACKER_ASSET_HOST"]).to eq "foo.bar"
  end

  describe "precompile hook" do
    it "runs precompile_hook before webpack when configured" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: true, exitstatus: 0)
      webpack_status = OpenStruct.new(success?: true)

      # Mock to track hook call and allow subsequent webpack call
      call_count = 0
      allow(Open3).to receive(:capture3) do |*args|
        call_count += 1
        if call_count == 1 && args[1] == "bin/test-hook"
          ["Hook output", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      # Temporarily stub config to return hook
      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/test-hook")

      expect(Shakapacker.compiler.compile).to be true
      expect(call_count).to eq(2) # Both hook and webpack were called
    end

    it "does not run precompile_hook when not configured" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      webpack_status = OpenStruct.new(success?: true)
      call_count = 0
      allow(Open3).to receive(:capture3) do |*args|
        call_count += 1
        ["", "", webpack_status]
      end

      # Config returns nil for precompile_hook (default)
      expect(Shakapacker.config.precompile_hook).to be_nil

      expect(Shakapacker.compiler.compile).to be true
      expect(call_count).to eq(1) # Only webpack was called
    end

    it "raises error when precompile_hook fails" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: false, exitstatus: 1)
      allow(Open3).to receive(:capture3).and_return(["", "Error output", hook_status])

      # Temporarily stub config to return failing hook
      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/failing-hook")

      expect { Shakapacker.compiler.compile }.to raise_error(/Precompile hook 'bin\/failing-hook' failed/)
    end

    it "handles hook with both stdout and stderr" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: true, exitstatus: 0)
      webpack_status = OpenStruct.new(success?: true)

      call_count = 0
      allow(Open3).to receive(:capture3) do |*args|
        call_count += 1
        if call_count == 1
          ["Standard output", "Warning message", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/verbose-hook")

      expect(Shakapacker.compiler.compile).to be true
    end

    it "validates hook is within project root" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      allow(Shakapacker.config).to receive(:precompile_hook).and_return("/etc/passwd")

      expect { Shakapacker.compiler.compile }.to raise_error(/Security Error.*must reference a script within the project root/)
    end

    it "warns when hook executable does not exist" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: true, exitstatus: 0)
      webpack_status = OpenStruct.new(success?: true)

      call_count = 0
      allow(Open3).to receive(:capture3) do |*args|
        call_count += 1
        if call_count == 1
          ["", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/nonexistent-hook")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(anything).and_return(false)

      expect(Shakapacker.logger).to receive(:warn).with(/executable not found/).at_least(:once)
      expect(Shakapacker.logger).to receive(:warn).at_least(:once)
      expect(Shakapacker.compiler.compile).to be true
    end
  end
end
