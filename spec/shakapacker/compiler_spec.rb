require_relative "spec_helper_initializer"

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

    status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).and_return([:stderr, :stdout, status])

    expect(Shakapacker.compiler.compile).to be true
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "passes configured webpack compile flags to the shakapacker binstub" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
    allow(Shakapacker.config).to receive(:webpack_compile_flags).and_return(["--progress", "--fail-on-warnings"])

    status = instance_double(Process::Status, success?: true)
    captured_args = nil
    allow(Open3).to receive(:capture3) do |_env, *args|
      captured_args = args
      ["", "", status]
    end

    expect(Shakapacker.compiler.compile).to be true
    expect(Open3).to have_received(:capture3).once

    command_args = captured_args.take_while { |arg| !arg.is_a?(Hash) }
    separator_index = command_args.index("--")
    expect(separator_index).not_to be nil
    expect(command_args[(separator_index + 1)..]).to eq(["--progress", "--fail-on-warnings"])
  end

  it "passes configured webpack compile flags after the Ruby runner when present" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
    allow(Shakapacker.config).to receive(:webpack_compile_flags).and_return(["--progress"])
    allow(Shakapacker.compiler).to receive(:optional_ruby_runner).and_return(RbConfig.ruby)

    status = instance_double(Process::Status, success?: true)
    captured_args = nil
    allow(Open3).to receive(:capture3) do |_env, *args|
      captured_args = args
      ["", "", status]
    end

    expect(Shakapacker.compiler.compile).to be true
    expect(Open3).to have_received(:capture3).once

    command_args = captured_args.take_while { |arg| !arg.is_a?(Hash) }
    bin_path = Shakapacker.config.root_path.join("bin/shakapacker").to_s
    expect(command_args).to eq([RbConfig.ruby, bin_path, "--", "--progress"])
  end

  it "uses exec argv form with configured webpack compile flags when no Ruby runner is present" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
    allow(Shakapacker.config).to receive(:webpack_compile_flags).and_return(["--progress"])
    allow(Shakapacker.compiler).to receive(:optional_ruby_runner).and_return("")

    status = instance_double(Process::Status, success?: true)
    captured_args = nil
    allow(Open3).to receive(:capture3) do |_env, *args|
      captured_args = args
      ["", "", status]
    end

    expect(Shakapacker.compiler.compile).to be true
    expect(Open3).to have_received(:capture3).once

    command_args = captured_args.take_while { |arg| !arg.is_a?(Hash) }
    bin_path = Shakapacker.config.root_path.join("bin/shakapacker").to_s
    expect(command_args).to eq([[bin_path, bin_path], "--", "--progress"])
  end

  it "uses exec argv form when no Ruby runner or compile flags are present" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
    allow(Shakapacker.config).to receive(:webpack_compile_flags).and_return([])
    allow(Shakapacker.compiler).to receive(:optional_ruby_runner).and_return("")

    status = instance_double(Process::Status, success?: true)
    captured_args = nil
    allow(Open3).to receive(:capture3) do |_env, *args|
      captured_args = args
      ["", "", status]
    end

    expect(Shakapacker.compiler.compile).to be true
    expect(Open3).to have_received(:capture3).once

    command_args = captured_args.take_while { |arg| !arg.is_a?(Hash) }
    bin_path = Shakapacker.config.root_path.join("bin/shakapacker").to_s
    expect(command_args).to eq([[bin_path, bin_path]])
  end

  it "uses exec argv form when the shakapacker binstub is empty" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
    allow(Shakapacker.config).to receive(:webpack_compile_flags).and_return([])

    bin_pathname = Shakapacker.config.root_path.join("bin/shakapacker")
    allow(File).to receive(:readlines).and_call_original
    allow(File).to receive(:readlines).with(bin_pathname).and_return([])

    status = instance_double(Process::Status, success?: true)
    captured_args = nil
    allow(Open3).to receive(:capture3) do |_env, *args|
      captured_args = args
      ["", "", status]
    end

    expect(Shakapacker.compiler.compile).to be true

    command_args = captured_args.take_while { |arg| !arg.is_a?(Hash) }
    bin_path = bin_pathname.to_s
    expect(command_args).to eq([[bin_path, bin_path]])
  end

  it "returns false and calls after_compile_hook on failed compile" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(mocked_strategy).to receive(:after_compile_hook)

    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

    status = instance_double(Process::Status, success?: false)
    allow(Open3).to receive(:capture3).and_return([:stderr, :stdout, status])

    expect(Shakapacker.compiler.compile).to be false
    expect(mocked_strategy).to have_received(:after_compile_hook)
  end

  it "returns false without after_compile_hook when the binstub cannot be spawned" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(mocked_strategy).to receive(:after_compile_hook)

    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
    allow(Open3).to receive(:capture3).and_raise(Errno::EACCES.new("bin/shakapacker"))
    allow(Shakapacker.logger).to receive(:error)
    allow(Shakapacker.logger).to receive(:info)
    Shakapacker::Compiler.doctor_hint_shown = false

    expect(Shakapacker.compiler.compile).to be false
    expect(Shakapacker.logger).to have_received(:error).with(/COMPILATION FAILED:\nErrno::EACCES:/)
    expect(Shakapacker.logger).to have_received(:info).with(/shakapacker:doctor/).once
    expect(mocked_strategy).not_to have_received(:after_compile_hook)
  end

  it "returns false with structured logging when the binstub is missing" do
    mocked_strategy = spy("Strategy")
    allow(mocked_strategy).to receive(:stale?).and_return(true)
    allow(mocked_strategy).to receive(:after_compile_hook)

    allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
    allow(Shakapacker.config).to receive(:webpack_compile_flags).and_return([])
    bin_pathname = Shakapacker.config.root_path.join("bin/shakapacker")
    allow(File).to receive(:readlines).and_call_original
    allow(File).to receive(:readlines).with(bin_pathname).and_raise(Errno::ENOENT.new("bin/shakapacker"))
    allow(Open3).to receive(:capture3)
    allow(Shakapacker.logger).to receive(:error)
    allow(Shakapacker.logger).to receive(:info)
    Shakapacker::Compiler.doctor_hint_shown = false

    expect(Shakapacker.compiler.compile).to be false
    expect(Open3).not_to have_received(:capture3)
    expect(Shakapacker.logger).to have_received(:error).with(/COMPILATION FAILED:\nErrno::ENOENT:/)
    expect(Shakapacker.logger).to have_received(:info).with(/shakapacker:doctor/).once
    expect(mocked_strategy).not_to have_received(:after_compile_hook)
  end

  describe "doctor hint messages" do
    let(:mocked_strategy) do
      spy("Strategy").tap do |s|
        allow(s).to receive(:stale?).and_return(true)
        allow(s).to receive(:after_compile_hook)
      end
    end

    before do
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)
      Shakapacker::Compiler.doctor_hint_shown = false
    end

    it "does not log the doctor hint when compilation succeeds" do
      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return(["", "", status])
      allow(Shakapacker.logger).to receive(:info)

      Shakapacker.compiler.compile

      expect(Shakapacker.logger).not_to have_received(:info).with(/shakapacker:doctor/)
    end

    it "logs the doctor hint after a failed compilation" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(["", "build error", status])
      allow(Shakapacker.logger).to receive(:error)
      allow(Shakapacker.logger).to receive(:info)

      Shakapacker.compiler.compile

      expect(Shakapacker.logger).to have_received(:info).with(/shakapacker:doctor/).once
    end

    it "sets the doctor hint flag without bypassing method visibility" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(["", "build error", status])
      allow(Shakapacker.logger).to receive(:error)
      allow(Shakapacker.logger).to receive(:info)
      allow(Shakapacker::Compiler).to receive(:send).and_call_original

      Shakapacker.compiler.compile

      expect(Shakapacker::Compiler).not_to have_received(:send).with(:doctor_hint_shown=, true)
      expect(Shakapacker::Compiler.doctor_hint_shown).to be true
    end

    it "does not repeat the doctor hint on subsequent failed compiles" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(["", "build error", status])
      allow(Shakapacker.logger).to receive(:error)
      allow(Shakapacker.logger).to receive(:info)

      Shakapacker.compiler.compile
      Shakapacker.compiler.compile

      expect(Shakapacker.logger).to have_received(:info).with(/shakapacker:doctor/).once
    end

    it "does not abort the build when the hint logger raises" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(["", "build error", status])
      allow(Shakapacker.logger).to receive(:error)
      # Generic stub first so the more specific stub below wins for matching args.
      allow(Shakapacker.logger).to receive(:info)
      allow(Shakapacker.logger).to receive(:info).with(/shakapacker:doctor/).and_raise("logger boom")

      expect { Shakapacker.compiler.compile }.not_to raise_error
      # Flag stays false so a future compile can still surface the tip when the logger recovers.
      expect(Shakapacker::Compiler.doctor_hint_shown).to be false
    end

    it "does not swallow failures outside the hint logger call" do
      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(["", "build error", status])
      allow(Shakapacker.logger).to receive(:error)
      allow(Shakapacker.logger).to receive(:info)
      allow(Shakapacker::Compiler).to receive(:doctor_hint_shown=).and_call_original
      allow(Shakapacker::Compiler).to receive(:doctor_hint_shown=).with(true).and_raise("flag boom")

      expect { Shakapacker.compiler.compile }.to raise_error("flag boom")
    end
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

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
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

      webpack_status = instance_double(Process::Status, success?: true)
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

      hook_status = instance_double(Process::Status, success?: false, exitstatus: 1)
      allow(Open3).to receive(:capture3).and_return(["", "Error output", hook_status])

      # Temporarily stub config to return failing hook
      allow(Shakapacker.config).to receive(:precompile_hook).and_return("bin/failing-hook")

      expect { Shakapacker.compiler.compile }.to raise_error(/Precompile hook 'bin\/failing-hook' failed/)
    end

    it "handles hook with both stdout and stderr" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
      hook_command = "bin/verbose-hook"
      hook_executable = hook_command

      allow(Open3).to receive(:capture3) do |env, *args|
        if args[0] == hook_executable
          ["Standard output", "Warning message", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)

      expect(Shakapacker.compiler.compile).to be true
      expect(Open3).to have_received(:capture3).with(hash_including, hook_executable, hash_including).once
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

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
      hook_command = "'bin/my script' --arg1 --arg2"
      hook_executable = "bin/my script"

      allow(Open3).to receive(:capture3) do |env, *args|
        if args[0] == hook_executable
          ["", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      # Hook command with quoted path containing spaces
      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(anything).and_return(true)

      expect(Shakapacker.compiler.compile).to be true
      expect(Open3).to have_received(:capture3).with(hash_including, hook_executable, "--arg1", "--arg2", hash_including).once
    end

    it "warns when hook executable does not exist" do
      mocked_strategy = spy("Strategy")
      allow(mocked_strategy).to receive(:stale?).and_return(true)
      allow(Shakapacker.compiler).to receive(:strategy).and_return(mocked_strategy)

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
      hook_command = "bin/nonexistent-hook"
      hook_executable = hook_command

      allow(Open3).to receive(:capture3) do |env, *args|
        if args[0] == hook_executable
          ["", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(anything).and_return(false)

      expect(Shakapacker.logger).to receive(:warn).with(/executable not found/).at_least(:once)
      expect(Shakapacker.logger).to receive(:warn).at_least(:once)
      expect(Shakapacker.compiler.compile).to be true
      expect(Open3).to have_received(:capture3).with(hash_including, hook_executable, hash_including).once
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

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
      hook_command = "bin/prepare && rm -rf /"
      hook_executable = "bin/prepare"

      captured_args = []
      allow(Open3).to receive(:capture3) do |env, *args|
        captured_args << args if args[0] == hook_executable
        if args[0] == hook_executable
          ["", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      # This malicious command would execute "rm -rf /" if passed to a shell
      # With shell-free execution, it's treated as arguments to bin/prepare
      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)
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

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
      hook_command = "FOO=bar BAZ=qux bin/hook --arg"
      hook_executable = "bin/hook"

      captured_env = nil
      allow(Open3).to receive(:capture3) do |env, *args|
        captured_env = env if args[0] == hook_executable
        if args[0] == hook_executable
          ["", "", hook_status]
        else
          ["", "", webpack_status]
        end
      end

      allow(Shakapacker.config).to receive(:precompile_hook).and_return(hook_command)
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

      webpack_status = instance_double(Process::Status, success?: true)
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

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
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

      hook_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      webpack_status = instance_double(Process::Status, success?: true)
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
