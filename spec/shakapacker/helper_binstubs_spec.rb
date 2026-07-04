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
          scriptPath: __filename,
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

  def real_node_path
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
      .map { |dir| File.join(dir, "node") }
      .find { |candidate| File.file?(candidate) && File.executable?(candidate) }
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

    it "loads #{command} from the configured subdirectory client package root" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        client_path = File.join(app_path, "client")
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        FileUtils.mkdir_p(File.join(app_path, "config"))
        FileUtils.mkdir_p(File.join(client_path, "app/javascript"))
        File.write(
          File.join(app_path, "config/shakapacker.yml"),
          <<~YAML
            default: &default
              source_path: client/app/javascript

            development:
              <<: *default
          YAML
        )
        install_fake_node_script(client_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          { "SHAKAPACKER_BINSTUB_OUTPUT" => output_path },
          binstub_path,
          "--doctor",
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path),
          "scriptPath" => File.realpath(File.join(client_path, "node_modules/shakapacker/package/bin/#{command}.cjs")),
          "argv" => ["--doctor"]
        )
      end
    end

    it "falls back to the Rails-root #{command} package script when source_path is not a string" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        FileUtils.mkdir_p(File.join(app_path, "config"))
        File.write(
          File.join(app_path, "config/shakapacker.yml"),
          <<~YAML
            development:
              source_path:
                nested: true
          YAML
        )
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          { "SHAKAPACKER_BINSTUB_OUTPUT" => output_path },
          binstub_path,
          "--doctor",
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path),
          "scriptPath" => File.realpath(File.join(app_path, "node_modules/shakapacker/package/bin/#{command}.cjs")),
          "argv" => ["--doctor"]
        )
      end
    end

    it "falls back to the Rails-root #{command} package script when client dependencies are hoisted" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        client_path = File.join(app_path, "client")
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(client_path)
        File.write(File.join(client_path, "package.json"), JSON.generate("private" => true))
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        FileUtils.mkdir_p(File.join(app_path, "config"))
        FileUtils.mkdir_p(File.join(client_path, "app/javascript"))
        File.write(
          File.join(app_path, "config/shakapacker.yml"),
          <<~YAML
            default: &default
              source_path: client/app/javascript

            development:
              <<: *default
          YAML
        )
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          { "SHAKAPACKER_BINSTUB_OUTPUT" => output_path },
          binstub_path,
          "--doctor",
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path),
          "scriptPath" => File.realpath(File.join(app_path, "node_modules/shakapacker/package/bin/#{command}.cjs")),
          "argv" => ["--doctor"]
        )
      end
    end

    it "uses the production #{command} source_path fallback for missing custom environments" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        client_path = File.join(app_path, "client")
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        FileUtils.mkdir_p(File.join(app_path, "config"))
        FileUtils.mkdir_p(File.join(app_path, "app/javascript"))
        FileUtils.mkdir_p(File.join(client_path, "app/javascript"))
        File.write(
          File.join(app_path, "config/shakapacker.yml"),
          <<~YAML
            default: &default
              source_path: app/javascript

            production:
              <<: *default
              source_path: client/app/javascript
          YAML
        )
        install_fake_node_script(client_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          { "RAILS_ENV" => "staging", "SHAKAPACKER_BINSTUB_OUTPUT" => output_path },
          binstub_path,
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path),
          "scriptPath" => File.realpath(File.join(client_path, "node_modules/shakapacker/package/bin/#{command}.cjs"))
        )
      end
    end

    it "does not use a bare default #{command} source_path fallback" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        client_path = File.join(app_path, "client")
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        FileUtils.mkdir_p(File.join(app_path, "config"))
        FileUtils.mkdir_p(File.join(client_path, "app/javascript"))
        File.write(
          File.join(app_path, "config/shakapacker.yml"),
          <<~YAML
            default:
              source_path: client/app/javascript
          YAML
        )
        install_fake_node_script(app_path, command)
        install_fake_node_script(client_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          { "RAILS_ENV" => "staging", "SHAKAPACKER_BINSTUB_OUTPUT" => output_path },
          binstub_path,
          chdir: app_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path),
          "scriptPath" => File.realpath(File.join(app_path, "node_modules/shakapacker/package/bin/#{command}.cjs"))
        )
      end
    end

    it "resolves a relative SHAKAPACKER_CONFIG for #{command} from the Rails root" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        client_path = File.join(app_path, "client")
        launch_path = File.join(app_path, "tmp/launch")
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        FileUtils.mkdir_p(File.join(app_path, "config"))
        FileUtils.mkdir_p(File.join(client_path, "app/javascript"))
        FileUtils.mkdir_p(launch_path)
        File.write(
          File.join(app_path, "config/custom-shakapacker.yml"),
          <<~YAML
            default: &default
              source_path: client/app/javascript

            production:
              <<: *default
          YAML
        )
        install_fake_node_script(client_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Open3.capture3(
          {
            "SHAKAPACKER_CONFIG" => "config/custom-shakapacker.yml",
            "SHAKAPACKER_BINSTUB_OUTPUT" => output_path
          },
          binstub_path,
          chdir: launch_path
        )

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path),
          "scriptPath" => File.realpath(File.join(client_path, "node_modules/shakapacker/package/bin/#{command}.cjs"))
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

        node_path = real_node_path

        skip "node not found in PATH" unless node_path

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
          exec #{node_path.shellescape} "$@"
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

    it "delegates unset PATH handling to Ruby's native exec for #{command}" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        wrapper_path = File.join(app_path, "capture_exec.rb")
        File.write(wrapper_path, <<~RUBY)
          require "json"

          module Kernel
            def exec(*args)
              File.write(ENV.fetch("SHAKAPACKER_EXEC_ARGS_OUTPUT"), JSON.generate(args))
              exit 0
            end
          end

          binstub_path = ARGV.fetch(0)
          ARGV.replace([])
          load binstub_path
        RUBY

        exec_args_path = File.join(app_path, "exec-args.json")
        _stdout, stderr, status = Bundler.with_unbundled_env do
          Open3.capture3(
            {
              "BUNDLE_GEMFILE" => nil,
              "PATH" => nil,
              "RUBYOPT" => nil,
              "SHAKAPACKER_EXEC_ARGS_OUTPUT" => exec_args_path
            },
            RbConfig.ruby,
            wrapper_path,
            binstub_path,
            chdir: app_path
          )
        end

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(exec_args_path))).to eq(
          ["node", File.realpath(File.join(app_path, "node_modules/shakapacker/package/bin/#{command}.cjs"))]
        )
      end
    end

    it "honors a relative PATH entry from the launch directory for #{command}" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        node_path = real_node_path
        skip "node not found in PATH" unless node_path

        launch_path = File.join(app_path, "launch")
        relative_bin_path = File.join(launch_path, "relative-bin")
        FileUtils.mkdir_p(relative_bin_path)
        fake_node_path = File.join(relative_bin_path, "node")
        File.write(fake_node_path, <<~SH)
          #!/bin/sh
          exec #{node_path.shellescape} "$@"
        SH
        FileUtils.chmod(0o755, fake_node_path)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        output_path = File.join(app_path, "binstub-output.json")
        _stdout, stderr, status = Bundler.with_unbundled_env do
          Open3.capture3(
            {
              "BUNDLE_GEMFILE" => nil,
              "PATH" => "relative-bin#{File::PATH_SEPARATOR}/nonexistent",
              "RUBYOPT" => nil,
              "SHAKAPACKER_BINSTUB_OUTPUT" => output_path
            },
            RbConfig.ruby,
            binstub_path,
            chdir: launch_path
          )
        end

        expect(status).to be_success, stderr
        expect(JSON.parse(File.read(output_path))).to include(
          "cwd" => File.realpath(app_path)
        )
      end
    end

    {
      "leading" => "#{File::PATH_SEPARATOR}/nonexistent",
      "trailing" => "/nonexistent#{File::PATH_SEPARATOR}"
    }.each do |position, path_value|
      it "honors a #{position} empty PATH entry as the current directory for #{command}" do
        Dir.mktmpdir("shakapacker-binstub-") do |app_path|
          File.write(File.join(app_path, "Gemfile"), "")
          FileUtils.mkdir_p(File.join(app_path, "bin"))
          install_fake_node_script(app_path, command)

          node_path = real_node_path
          skip "node not found in PATH" unless node_path

          launch_path = File.join(app_path, "launch")
          FileUtils.mkdir_p(launch_path)
          fake_node_path = File.join(launch_path, "node")
          File.write(fake_node_path, <<~SH)
            #!/bin/sh
            exec #{node_path.shellescape} "$@"
          SH
          FileUtils.chmod(0o755, fake_node_path)

          binstub_path = File.join(app_path, "bin", command)
          FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
          FileUtils.chmod(0o755, binstub_path)

          output_path = File.join(app_path, "binstub-output.json")
          _stdout, stderr, status = Bundler.with_unbundled_env do
            Open3.capture3(
              {
                "BUNDLE_GEMFILE" => nil,
                "PATH" => path_value,
                "RUBYOPT" => nil,
                "SHAKAPACKER_BINSTUB_OUTPUT" => output_path
              },
              RbConfig.ruby,
              binstub_path,
              chdir: launch_path
            )
          end

          expect(status).to be_success, stderr
          expect(JSON.parse(File.read(output_path))).to include(
            "cwd" => File.realpath(app_path)
          )
        end
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

        _stdout, stderr, status = Bundler.with_unbundled_env do
          Open3.capture3(
            { "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil, "PATH" => "/nonexistent" },
            RbConfig.ruby,
            binstub_path,
            chdir: app_path
          )
        end

        expect(status.exitstatus).to eq(1)
        expect(stderr).to include('[Shakapacker] Could not find Node.js executable "node"')
      end
    end

    it "exits with a contextual error when native exec reports node is not executable for #{command}" do
      Dir.mktmpdir("shakapacker-binstub-") do |app_path|
        File.write(File.join(app_path, "Gemfile"), "")
        FileUtils.mkdir_p(File.join(app_path, "bin"))
        install_fake_node_script(app_path, command)

        binstub_path = File.join(app_path, "bin", command)
        FileUtils.cp(File.join(gem_root, "lib", "install", "bin", command), binstub_path)
        FileUtils.chmod(0o755, binstub_path)

        wrapper_path = File.join(app_path, "deny_exec.rb")
        File.write(wrapper_path, <<~RUBY)
          module Kernel
            def exec(*)
              raise Errno::EACCES, "node"
            end
          end

          binstub_path = ARGV.fetch(0)
          ARGV.replace([])
          load binstub_path
        RUBY

        _stdout, stderr, status = Bundler.with_unbundled_env do
          Open3.capture3(
            { "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil },
            RbConfig.ruby,
            wrapper_path,
            binstub_path,
            chdir: app_path
          )
        end

        expect(status.exitstatus).to eq(1)
        expect(stderr).to include('[Shakapacker] Could not find Node.js executable "node"')
      end
    end
  end
end
