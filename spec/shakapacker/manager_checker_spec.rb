require_relative "spec_helper_initializer"
require "shakapacker/version"

Struct.new("Status", :exit_code) do
  def success?
    exit_code.zero?
  end

  def exitstatus
    exit_code
  end
end

def within_temp_directory(tmpdir = nil, &block)
  Dir.mktmpdir("shakapacker-", tmpdir) do |dir|
    Dir.chdir(dir, &block)
  end
end

describe "ManagerChecker" do
  around do |example|
    within_temp_directory { example.run }
  end

  describe "#warn_unless_package_manager_is_obvious!" do
    before do
      allow(Shakapacker).to receive(:puts_deprecation_message)
    end

    context "when 'packageManager' is set in the package.json" do
      before do
        File.write("package.json", { "packageManager" => "pnpm" }.to_json)
      end

      it "does nothing" do
        Shakapacker::ManagerChecker.new.warn_unless_package_manager_is_obvious!

        expect(Shakapacker).not_to have_received(:puts_deprecation_message)
      end
    end

    context "when the guessed manager is npm" do
      it "does nothing" do
        File.write("package.json", {}.to_json)
        FileUtils.touch("package-lock.json")

        Shakapacker::ManagerChecker.new.warn_unless_package_manager_is_obvious!

        expect(Shakapacker).not_to have_received(:puts_deprecation_message)
      end
    end

    Shakapacker::ManagerChecker::MANAGER_LOCKS.reject { |manager| manager == :npm }.each do |manager, lock|
      context "when there is a #{lock}" do
        before do
          allow(Open3).to receive(:capture3).and_return(["1.2.3\n", "", Struct::Status.new(0)])
        end

        it "recommends setting 'packageManager' for #{manager}" do
          File.write("package.json", {}.to_json)
          FileUtils.touch(lock)

          Shakapacker::ManagerChecker.new.warn_unless_package_manager_is_obvious!

          expect(Shakapacker).to have_received(:puts_deprecation_message).with(<<~MSG)
            You have not got "packageManager" set in your package.json meaning that Shakapacker will use npm
            but you've got a #{lock} file meaning you probably want
            to be using #{manager} instead.

            To make this happen, set "packageManager" in your package.json to #{manager}@1.2.3
          MSG
        end
      end
    end
  end

  describe "#package_manager_set?" do
    it "returns true when the 'packageManager' property is set" do
      File.write("package.json", { "packageManager" => "npm" }.to_json)

      expect(Shakapacker::ManagerChecker.new.package_manager_set?).to be true
    end

    it "returns false when the 'packageManager' property is not set" do
      File.write("package.json", {}.to_json)

      expect(Shakapacker::ManagerChecker.new.package_manager_set?).to be false
    end
  end

  describe "#guess_manager_version" do
    before do
      allow(Open3).to receive(:capture3).and_return(["1.2.3\n", "", Struct::Status.new(0)])
    end

    Shakapacker::ManagerChecker::MANAGER_LOCKS.each do |manager, lock|
      context "when a #{lock} exists" do
        before { FileUtils.touch(lock) }

        it "calls #{manager} with --version" do
          Shakapacker::ManagerChecker.new.guess_manager_version

          expect(Open3).to have_received(:capture3).with("#{manager} --version")
        end
      end
    end

    it "returns the output without a trailing newline" do
      FileUtils.touch("package-lock.json")

      expect(Shakapacker::ManagerChecker.new.guess_manager_version).to eq("1.2.3")
    end

    context "when the command errors" do
      before do
        allow(Open3).to receive(:capture3).and_return(["", "oh noes!", Struct::Status.new(1)])
      end

      it "raises an error" do
        FileUtils.touch("package-lock.json")

        expect { Shakapacker::ManagerChecker.new.guess_manager_version }.to raise_error(
          Shakapacker::ManagerChecker::Error,
          "npm --version failed with exit code 1: oh noes!"
        )
      end
    end
  end

  describe "#guess_manager" do
    Shakapacker::ManagerChecker::MANAGER_LOCKS.each do |manager, lock|
      context "when a #{lock} exists" do
        before { FileUtils.touch(lock) }

        it "guesses #{manager}" do
          expect(Shakapacker::ManagerChecker.new.guess_manager).to eq manager
        end
      end
    end

    context "when there is no lockfile" do
      it "returns npm" do
        expect(Shakapacker::ManagerChecker.new.guess_manager).to eq :npm
      end
    end
  end
end
