require "fileutils"
require "pathname"
require "rake"
require "rbconfig"
require "stringio"
require "tmpdir"

RSpec.describe "shakapacker:export_bundler_config" do
  let(:task_name) { "shakapacker:export_bundler_config" }
  let(:task_path) { File.expand_path("../../lib/tasks/shakapacker/export_bundler_config.rake", __dir__) }

  around do |example|
    original_application = Rake.application
    original_argv = ARGV.dup

    Rake.application = Rake::Application.new
    load task_path

    example.run
  ensure
    ARGV.replace(original_argv)
    Rake.application = original_application
  end

  def write_app_binstub(app_path, content)
    binstub_path = File.join(app_path, "bin", "shakapacker-config")
    FileUtils.mkdir_p(File.dirname(binstub_path))
    File.write(binstub_path, content)
    FileUtils.chmod(0o755, binstub_path)
    binstub_path
  end

  def invoke_task(app_path, *args, exec_error: nil)
    captured_exec = nil
    stub_const("Rails", double(root: Pathname.new(app_path)))
    allow(Kernel).to receive(:exec) do |*exec_args|
      raise exec_error if exec_error

      captured_exec = exec_args
    end

    ARGV.replace([task_name, *args])
    Rake::Task[task_name].invoke

    captured_exec
  end

  def capture_stderr
    stderr_output = StringIO.new
    original_stderr = $stderr
    $stderr = stderr_output
    yield stderr_output
  ensure
    $stderr = original_stderr
  end

  it "runs upgraded apps' legacy JavaScript binstub with node" do
    Dir.mktmpdir("shakapacker-export-bundler-config-") do |app_path|
      binstub_path = write_app_binstub(app_path, <<~JS)
        #!/usr/bin/env node
        console.log("legacy binstub")
      JS

      stderr_output = StringIO.new
      allow($stderr).to receive(:puts) { |message| stderr_output.puts(message) }

      expect(invoke_task(app_path, "--doctor")).to eq(["node", binstub_path, "--doctor"])
      expect(stderr_output.string).to include("legacy JavaScript binstub")
      expect(stderr_output.string).to include("rake shakapacker:binstubs")
    end
  end

  it "runs nodejs legacy binstubs with nodejs and warns about the legacy binstub" do
    Dir.mktmpdir("shakapacker-export-bundler-config-") do |app_path|
      binstub_path = write_app_binstub(app_path, <<~JS)
        #!/usr/bin/env nodejs
        console.log("legacy binstub")
      JS

      stderr_output = StringIO.new
      allow($stderr).to receive(:puts) { |message| stderr_output.puts(message) }

      expect(invoke_task(app_path, "--doctor")).to eq(
        ["nodejs", binstub_path, "--doctor"]
      )
      expect(stderr_output.string).to include("legacy JavaScript binstub")
      expect(stderr_output.string).to include("rake shakapacker:binstubs")
    end
  end

  it "aborts with upgrade guidance when a legacy JavaScript binstub executable is missing" do
    Dir.mktmpdir("shakapacker-export-bundler-config-") do |app_path|
      write_app_binstub(app_path, <<~JS)
        #!/usr/bin/env node
        console.log("legacy binstub")
      JS

      capture_stderr do |stderr_output|
        expect { invoke_task(app_path, "--doctor", exec_error: Errno::ENOENT.new) }.to raise_error(SystemExit)
        expect(stderr_output.string).to include("'node' was not found in PATH")
        expect(stderr_output.string).to include("rake shakapacker:binstubs")
      end
    end
  end

  it "runs Ruby binstubs with the current Ruby interpreter" do
    Dir.mktmpdir("shakapacker-export-bundler-config-") do |app_path|
      binstub_path = write_app_binstub(app_path, <<~RUBY)
        #!/usr/bin/env ruby
        puts "ruby binstub"
      RUBY

      expect(invoke_task(app_path, "--save")).to eq([RbConfig.ruby, binstub_path, "--save"])
    end
  end
end
