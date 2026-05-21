require "spec_helper"
require "fileutils"
require "tempfile"
require "shakapacker/utils/misc"

RSpec.describe Shakapacker::Utils::Misc do
  describe ".js_binstub?" do
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

    it "returns true for a node `env` shebang" do
      with_binstub("#!/usr/bin/env node\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub?(path)).to be true
      end
    end

    it "returns true for a direct node shebang" do
      with_binstub("#!/usr/local/bin/node\nconsole.log('legacy')\n") do |path|
        expect(described_class.js_binstub?(path)).to be true
      end
    end

    it "returns false for a ruby `env` shebang" do
      with_binstub("#!/usr/bin/env ruby\nputs 'ruby'\n") do |path|
        expect(described_class.js_binstub?(path)).to be false
      end
    end

    it "returns false for a direct ruby shebang" do
      with_binstub("#!/usr/bin/ruby\nputs 'ruby'\n") do |path|
        expect(described_class.js_binstub?(path)).to be false
      end
    end

    it "returns false when the file has no shebang" do
      with_binstub("just text\n") do |path|
        expect(described_class.js_binstub?(path)).to be false
      end
    end

    it "returns false for an empty file" do
      with_binstub("") do |path|
        expect(described_class.js_binstub?(path)).to be false
      end
    end

    it "returns false when the path does not exist" do
      expect(described_class.js_binstub?("/no/such/path/anywhere")).to be false
    end

    it "returns false when the path is a directory" do
      Dir.mktmpdir do |dir|
        expect(described_class.js_binstub?(dir)).to be false
      end
    end
  end
end
