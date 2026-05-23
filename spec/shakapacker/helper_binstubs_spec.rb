require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "shellwords"
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
          argv: process.argv.slice(2),
          env: {
            RAILS_ENV: process.env.RAILS_ENV,
            NODE_ENV: process.env.NODE_ENV
          }
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
        expect(JSON.parse(File.read(output_path))).to include(
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
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path),
          "argv" => []
        )
        expect(stderr).to include("[Shakapacker] No Gemfile found at")
      end
    end

    it "sets NODE_ENV from RAILS_ENV when NODE_ENV is unset for #{command}" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          {
            "NODE_ENV" => nil,
            "RAILS_ENV" => "production",
            "SHAKAPACKER_BINSTUB_OUTPUT" => output_path
          },
          binstub_path,
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "env" => include(
            "RAILS_ENV" => "production",
            "NODE_ENV" => "production"
          )
        )
      end
    end

    it "maps RAILS_ENV=test to NODE_ENV=development for #{command}" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          {
            "NODE_ENV" => nil,
            "RAILS_ENV" => "test",
            "SHAKAPACKER_BINSTUB_OUTPUT" => output_path
          },
          binstub_path,
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "env" => include(
            "RAILS_ENV" => "test",
            "NODE_ENV" => "development"
          )
        )
      end
    end

    it "does not execute node just to locate it for #{command}" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        real_node_path = ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { |path| File.join(path, "node") }.find do |path|
          File.file?(path) && File.executable?(path)
        end

        skip "node not found in PATH" unless real_node_path

        fake_bin_path = File.join(app_path, "fake-bin")
        FileUtils.mkdir_p(fake_bin_path)
        probe_output_path = File.join(app_path, "node-probe-output.txt")
        fake_node_path = File.join(fake_bin_path, "node")
        File.write(fake_node_path, <<~SH)
          #!/bin/sh
          if [ "$1" = "--version" ]; then
            echo probed >> "$SHAKAPACKER_NODE_PROBE_OUTPUT"
            exit 0
          fi
          exec #{real_node_path.shellescape} "$@"
        SH
        FileUtils.chmod(0o755, fake_node_path)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          {
            "PATH" => "#{fake_bin_path}#{File::PATH_SEPARATOR}#{ENV.fetch("PATH")}",
            "SHAKAPACKER_BINSTUB_OUTPUT" => output_path,
            "SHAKAPACKER_NODE_PROBE_OUTPUT" => probe_output_path
          },
          binstub_path,
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(File).not_to exist(probe_output_path)
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
