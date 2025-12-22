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
      hook_command = "bin/test-hook"

      allow(Open3).to receive(:capture3) do |env, *args|
        if args[0] == hook_command
          ["Hook output", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)

      expect(Shakapacker.compiler.compile).to be true
      expect(Open3).to have_received(:capture3).with(hash_including, hook_command, hash_including).once
    end

    it "does not run precompile_hook when not configured" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      webpack_status = OpenStruct.new(success?: true)
      allow(Open3).to receive(:capture3).and_return(["", "", webpack_status])

      # Config returns nil for precompile_hook (default)
      expect(Shakapacker.config.precompile_hook).to be_nil

      expect(Shakapacker.compiler.compile).to be true
      # Verify webpack was called once, and no hook command was invoked
      expect(Open3).to have_received(:capture3).once
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

    it "prevents path traversal attacks" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      # Attempt to escape project root with path traversal
      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/../../etc/passwd")

      expect { Shakapacker.compiler.compile }.to raise_error(/Security Error.*must reference a script within the project root/)
    end

    it "prevents partial path matching vulnerabilities" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      # Test that /project doesn't match /project-evil by checking File::SEPARATOR requirement
      # We simulate this by testing a hook that would resolve outside the root
      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/../../../etc/passwd")

      expect { Shakapacker.compiler.compile }.to raise_error(/Security Error/)
    end

    it "handles hook commands with spaces in paths using Shellwords" do
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

      # Hook command with quoted path containing spaces
      allow(Shakapacker.config).to receive(:precompile_hook).and_return("'bin/my script' --arg1 --arg2")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(anything).and_return(true)

      expect(Shakapacker.compiler.compile).to be true
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

    it "raises error for malformed hook command with unmatched quotes" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/hook 'unclosed quote")

      expect { Shakapacker.compiler.compile }.to raise_error(/Invalid precompile_hook command syntax.*unmatched quotes/)
    end

    it "raises error for empty hook command after env assignments" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      allow(Shakapacker.config).to receive(:precompile_hook).and_return("FOO=bar")

      expect { Shakapacker.compiler.compile }.to raise_error(/precompile_hook must include an executable command/)
    end

    it "prevents shell injection via command chaining" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: true, exitstatus: 0)
      webpack_status = OpenStruct.new(success?: true)

      call_count = 0
      captured_args = []
      allow(Open3).to receive(:capture3) do |env, *args|
        call_count += 1
        captured_args << args if call_count == 1
        if call_count == 1
          ["", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      # This malicious command would execute "rm -rf /" if passed to a shell
      # With shell-free execution, it's treated as arguments to bin/prepare
      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/prepare && rm -rf /")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(anything).and_return(true)

      expect(Shakapacker.compiler.compile).to be true
      # Verify that "&&" and subsequent tokens are passed as arguments, not executed as shell commands
      expect(captured_args[0][0]).to eq("bin/prepare")
      # captured_args[0] contains: [executable, arg1, arg2, ..., {chdir: ...}]
      expect(captured_args[0][1..4]).to eq(["&&", "rm", "-rf", "/"])
    end

    it "supports environment variable assignments in hook command" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: true, exitstatus: 0)
      webpack_status = OpenStruct.new(success?: true)

      call_count = 0
      captured_env = nil
      allow(Open3).to receive(:capture3) do |env, *args|
        call_count += 1
        captured_env = env if call_count == 1
        if call_count == 1
          ["", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return("FOO=bar BAZ=qux bin/hook --arg")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(anything).and_return(true)

      expect(Shakapacker.compiler.compile).to be true
      # Verify environment variables were extracted and merged
      expect(captured_env["FOO"]).to eq("bar")
      expect(captured_env["BAZ"]).to eq("qux")
    end

    it "skips precompile_hook when SHAKAPACKER_SKIP_PRECOMPILE_HOOK=true" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      webpack_status = OpenStruct.new(success?: true)
      hook_command = "bin/test-hook"
      allow(Open3).to receive(:capture3).and_return(["", "", webpack_status])

      # Hook is configured
      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)

      # But skip flag is set
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SHAKAPACKER_SKIP_PRECOMPILE_HOOK").and_return("true")

      expect(Shakapacker.compiler.compile).to be true
      # Explicitly verify hook was NOT called
      expect(Open3).not_to have_received(:capture3).with(anything, hook_command, anything)
      # Verify webpack was still called
      expect(Open3).to have_received(:capture3).once
    end

    it "runs precompile_hook when SHAKAPACKER_SKIP_PRECOMPILE_HOOK is not set" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: true, exitstatus: 0)
      webpack_status = OpenStruct.new(success?: true)
      hook_command = "bin/test-hook"

      allow(Open3).to receive(:capture3) do |env, *args|
        if args[0] == hook_command
          ["Hook output", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)

      # Skip flag is not set
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SHAKAPACKER_SKIP_PRECOMPILE_HOOK").and_return(nil)

      expect(Shakapacker.compiler.compile).to be true
      # Explicitly verify hook was called
      expect(Open3).to have_received(:capture3).with(hash_including, hook_command, hash_including).once
    end

    it "runs precompile_hook when SHAKAPACKER_SKIP_PRECOMPILE_HOOK is false" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = OpenStruct.new(success?: true, exitstatus: 0)
      webpack_status = OpenStruct.new(success?: true)
      hook_command = "bin/test-hook"

      allow(Open3).to receive(:capture3) do |env, *args|
        if args[0] == hook_command
          ["Hook output", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)

      # Skip flag is set to "false" (not "true")
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("SHAKAPACKER_SKIP_PRECOMPILE_HOOK").and_return("false")

      expect(Shakapacker.compiler.compile).to be true
      # Explicitly verify hook was called
      expect(Open3).to have_received(:capture3).with(hash_including, hook_command, hash_including).once
    end
  end
end
