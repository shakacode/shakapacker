RSpec.shared_examples "help and version flags" do |runner_class, help_header_text|
  describe "help and version flags" do
    it "prints custom help message for --help flag and exits" do
      expect { runner_class.run(["--help"]) }
        .to output(/#{Regexp.escape(help_header_text)}/).to_stdout
        .and raise_error(SystemExit)
    end

    it "prints custom help message for -h flag and exits" do
      expect { runner_class.run(["-h"]) }
        .to output(/#{Regexp.escape(help_header_text)}/).to_stdout
        .and raise_error(SystemExit)
    end

    it "includes Shakapacker-specific options in help" do
      expect { runner_class.run(["--help"]) }
        .to output(/--debug-shakapacker/).to_stdout
        .and raise_error(SystemExit)
    end

    it "shows options managed by Shakapacker" do
      expect { runner_class.run(["--help"]) }
        .to output(/Options managed by Shakapacker/).to_stdout
        .and raise_error(SystemExit)
    end

    it "shows common bundler options users can use" do
      expect { runner_class.run(["--help"]) }
        .to output(/options you can use/).to_stdout
        .and raise_error(SystemExit)
    end

    it "mentions config option is managed automatically" do
      expect { runner_class.run(["--help"]) }
        .to output(/--config.*Set automatically/).to_stdout
        .and raise_error(SystemExit)
    end

    it "prints version for --version flag and exits" do
      expect { runner_class.run(["--version"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
        .and raise_error(SystemExit)
    end

    it "prints version for -v flag and exits" do
      expect { runner_class.run(["-v"]) }
        .to output(/Shakapacker #{Shakapacker::VERSION}/).to_stdout
        .and raise_error(SystemExit)
    end

    it "prioritizes help over version when both flags are present" do
      expect { runner_class.run(["--help", "--version"]) }
        .to output(/#{Regexp.escape(help_header_text)}/).to_stdout
        .and raise_error(SystemExit)
    end
  end
end
