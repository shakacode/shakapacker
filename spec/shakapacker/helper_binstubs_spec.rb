require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe "helper binstubs" do
  let(:gem_root) { File.expand_path("../..", __dir__) }

  def install_fake_node_script(app_path, command)
    script_path = File.join(
      app_path,
      "node_modules",
      "shakapacker",
      "package",
      "bin",
      "#{command}.cjs"
    )
    FileUtils.mkdir_p(File.dirname(script_path))
    File.write(script_path, <<~JS)
      #!/usr/bin/env node

      const fs = require("fs")

      fs.writeFileSync(
        process.env.SHAKAPACKER_BINSTUB_OUTPUT,
        JSON.stringify({
          cwd: process.cwd(),
          argv: process.argv.slice(2)
        })
      )
    JS
    FileUtils.chmod(0o755, script_path)
  end

  %w[shakapacker-config diff-bundler-config].each do |command|
    it "runs #{command} through a CommonJS package script when the app is ESM" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        File.write(File.join(app_path, "package.json"), JSON.generate("type" => "module"))
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          { "SHAKAPACKER_BINSTUB_OUTPUT" => output_path },
          binstub_path,
          "--flag",
          "value",
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to eq(
          "cwd" => File.realpath(app_path),
          "argv" => ["--flag", "value"]
        )
      end
    end

    it "falls back to the current directory when #{command}'s parent has no Gemfile" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          { "SHAKAPACKER_BINSTUB_OUTPUT" => output_path },
          binstub_path,
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to eq(
          "cwd" => File.realpath(app_path),
          "argv" => []
        )
        expect(stderr).to include("[Shakapacker] No Gemfile found at")
      end
    end

    it "exits with an error when #{command}'s package script is missing" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        File.write(File.join(app_path, "package.json"), JSON.generate("type" => "module"))
        FileUtils.mkdir_p(File.join(app_path, "bin"))

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        _stdout, stderr, status = Open3.capture3(
          binstub_path,
          chdir: app_path
        )

        expect(status.exitstatus).to eq(1)
        expect(stderr).to match(
          %r{\[Shakapacker\] Could not find .*/node_modules/shakapacker/package/bin/#{Regexp.escape(command)}\.cjs}
        )
      end
    end

    it "exits with a contextual error when node is unavailable for #{command}" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        _stdout, stderr, status = Open3.capture3(
          { "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil, "PATH" => "/nonexistent" },
          RbConfig.ruby,
          binstub_path,
          chdir: app_path
        )

        expect(status.exitstatus).to eq(1)
        expect(stderr).to include('[Shakapacker] Could not find Node.js executable "node"')
      end
    end
  end
end
