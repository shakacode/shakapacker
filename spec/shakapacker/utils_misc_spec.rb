require "spec_helper"
require "fileutils"
require "tempfile"
require "shakapacker/utils/misc"

RSpec.describe Shakapacker::Utils::Misc do
  describe ".js_binstub_executable" do
    def with_binstub(contents)
      file = Tempfile.new(["binstub-", ""])
      file.binmode
      file.write(contents)
      file.close
      yield file.path
    ensure
      file&.close
      file&.unlink
    end

    it "returns node for a node `env` shebang" do
      with_binstub("#!/usr/bin/env node\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to eq "node"
      end
    end

    it "returns node for a node `env` shebang with CRLF line endings" do
      with_binstub("#!/usr/bin/env node\r\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to eq "node"
      end
    end

    it "returns node for a node `env` shebang with env flags" do
      with_binstub("#!/usr/bin/env -S node --no-warnings\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to eq "node"
      end
    end

    it "returns node for a node `env` shebang with env flags that take arguments" do
      with_binstub("#!/usr/bin/env -u NODE_PATH -C /tmp node\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to eq "node"
      end
    end

    it "returns the executable path for a direct node shebang" do
      with_binstub("#!/usr/local/bin/node\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to eq "/usr/local/bin/node"
      end
    end

    it "returns nodejs for a nodejs shebang" do
      with_binstub("#!/usr/bin/env nodejs\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to eq "nodejs"
      end
    end

    it "returns the executable path for a direct nodejs shebang" do
      with_binstub("#!/usr/bin/nodejs\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to eq "/usr/bin/nodejs"
      end
    end

    it "returns nil for a ruby `env` shebang" do
      with_binstub("#!/usr/bin/env ruby\nputs 'ruby'\n") do |path|
        expect(described_class.js_binstub_executable(path)).to be_nil
      end
    end

    it "returns nil for a direct ruby shebang" do
      with_binstub("#!/usr/bin/ruby\nputs 'ruby'\n") do |path|
        expect(described_class.js_binstub_executable(path)).to be_nil
      end
    end

    it "returns nil when node appears after the shebang interpreter" do
      with_binstub("#!/usr/bin/ruby node\nputs 'ruby'\n") do |path|
        expect(described_class.js_binstub_executable(path)).to be_nil
      end
    end

    it "returns nil for shebangs that only contain node as a substring" do
      with_binstub("#!/usr/bin/env nodemon\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to be_nil
      end
    end

    it "returns nil when the file has no shebang" do
      with_binstub("just text\n") do |path|
        expect(described_class.js_binstub_executable(path)).to be_nil
      end
    end

    it "returns nil for malformed shebangs" do
      with_binstub("#!/usr/bin/env 'node\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub_executable(path)).to be_nil
      end
    end

    it "returns nil for an empty file" do
      with_binstub("") do |path|
        expect(described_class.js_binstub_executable(path)).to be_nil
      end
    end

    it "returns nil when the path does not exist" do
      expect(
        described_class.js_binstub_executable("/no/such/path/anywhere")
      ).to be_nil
    end

    it "returns nil when the path is a directory" do
      Dir.mktmpdir do |dir|
        expect(described_class.js_binstub_executable(dir)).to be_nil
      end
    end
  end
end
