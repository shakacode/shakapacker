require_relative "spec_helper_initializer"
require "shakapacker/utils/manager"

Struct.new("Status", :exit_code) do
  def success?
    exit_code.zero?
  end

  def exitstatus
    exit_code
  end
end

describe "Shakapacker::Utils::Manager" do
  around do |example|
    within_temp_directory { example.run }
  end

  describe "~error_unless_package_manager_is_obvious!" do
    before do
      allow(Shakapacker).to receive(:puts_deprecation_message)
    end

    context "when 'packageManager' is set in the package.json" do
      before do
        File.write("package.json", { "packageManager" => "pnpm" }.to_json)
      end

      it "does nothing" do
        Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!

        expect(Shakapacker).not_to have_received(:puts_deprecation_message)
      end
    end

    context "when the guessed manager is npm" do
      it "does nothing" do
        File.write("package.json", {}.to_json)
        FileUtils.touch("package-lock.json")

        Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious!

        expect(Shakapacker).not_to have_received(:puts_deprecation_message)
      end
    end

    Shakapacker::Utils::Manager::MANAGER_LOCKS.reject { |manager| manager == "npm" }.each do |manager, lock|
      context "when there is a #{lock}" do
        before do
          allow(Open3).to receive(:capture3).and_return(["1.2.3\n", "", Struct::Status.new(0)])
        end

        it "raises an error about setting 'packageManager' for #{manager}" do
          File.write("package.json", {}.to_json)
          FileUtils.touch(lock)

          expect { Shakapacker::Utils::Manager.error_unless_package_manager_is_obvious! }.to raise_error(Shakapacker::Utils::Manager::Error, <<~MSG)
            You don't have "packageManager" set in your package.json
            meaning that Shakapacker will use npm but you've got a #{lock}
            file meaning you probably want to be using #{manager} instead.

            To make this happen, set "packageManager" in your package.json to #{manager}@1.2.3
          MSG
        end
      end
    end
  end

  describe "~guess_binary" do
    Shakapacker::Utils::Manager::MANAGER_LOCKS.each do |manager, lock|
      context "when a #{lock} exists" do
        before { FileUtils.touch(lock) }

        it "guesses #{manager}" do
          expect(Shakapacker::Utils::Manager.guess_binary).to eq manager
        end
      end
    end

    context "when there is no lockfile" do
      it "returns npm" do
        expect(Shakapacker::Utils::Manager.guess_binary).to eq "npm"
      end
    end
  end

  describe "~guess_version" do
    before do
      allow(Open3).to receive(:capture3).and_return(["1.2.3\n", "", Struct::Status.new(0)])
    end

    Shakapacker::Utils::Manager::MANAGER_LOCKS.each do |manager, lock|
      context "when a #{lock} exists" do
        before { FileUtils.touch(lock) }

        it "calls #{manager} with --version" do
          Shakapacker::Utils::Manager.guess_version

          expect(Open3).to have_received(:capture3).with("#{manager} --version")
        end
      end
    end

    it "returns the output without a trailing newline" do
      FileUtils.touch("package-lock.json")

      expect(Shakapacker::Utils::Manager.guess_version).to eq("1.2.3")
    end

    context "when the command errors" do
      before do
        allow(Open3).to receive(:capture3).and_return(["", "oh noes!", Struct::Status.new(1)])
      end

      it "raises an error" do
        FileUtils.touch("package-lock.json")

        expect { Shakapacker::Utils::Manager.guess_version }.to raise_error(
          Shakapacker::Utils::Manager::Error,
          "npm --version failed with exit code 1: oh noes!"
        )
      end
    end
  end
end
