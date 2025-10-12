RSpec.shared_examples "help and version flags" do |runner_class, help_header_text|
  describe "help and version flags" do
    before do
      allow(Shakapacker::Utils::Manager).to receive(:error_unless_package_manager_is_obvious!)
      allow(Kernel).to receive(:exec)
    end

    it "prints custom help message for --help flag" do
      expect { runner_class.run(["--help"]) }
        .to output(/#{Regexp.escape(help_header_text)}/).to_stdout
    end

    it "prints custom help message for -h flag" do
      expect { runner_class.run(["-h"]) }
        .to output(/#{Regexp.escape(help_header_text)}/).to_stdout
    end

    it "includes Shakapacker-specific options in help" do
      expect { runner_class.run(["--help"]) }
        .to output(/--debug-shakapacker/).to_stdout
    end

    it "shows separator before bundler options" do
      expect { runner_class.run(["--help"]) }
        .to output(/OPTIONS/).to_stdout
    end

    it "continues to pass --help through to bundler after showing Shakapacker help" do
      runner_class.run(["--help"])
      expect(Kernel).to have_received(:exec)
    end

    it "prints version for --version flag" do
      expect { runner_class.run(["--version"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
    end

    it "prints version for -v flag" do
      expect { runner_class.run(["-v"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
    end

    it "continues to pass --version through to bundler after showing Shakapacker version" do
      runner_class.run(["--version"])
      expect(Kernel).to have_received(:exec)
    end

    it "prioritizes help over version when both flags are present" do
      expect { runner_class.run(["--help", "--version"]) }
        .to output(/#{Regexp.escape(help_header_text)}/).to_stdout
      expect(Kernel).to have_received(:exec)
    end
  end
end
