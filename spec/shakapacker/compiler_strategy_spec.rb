require_relative "spec_helper_initializer"

describe "Shakapacker::CompilerStrategy" do
  describe "#from_config" do
    it "returns an instance of MtimeStrategy when compiler_strategy is set to mtime" do
      allow(Shakapacker.config).to receive(:compiler_strategy).and_return("mtime")

      expect(Shakapacker::CompilerStrategy.from_config(Shakapacker.instance)).to be_an_instance_of(Shakapacker::MtimeStrategy)
    end

    it "returns an instance of DigestStrategy when compiler_strategy is set to digest" do
      allow(Shakapacker.config).to receive(:compiler_strategy).and_return("digest")

      expect(Shakapacker::CompilerStrategy.from_config(Shakapacker.instance)).to be_an_instance_of(Shakapacker::DigestStrategy)
    end

    it "raise an exception for unknown compiler_strategy in the config file" do
      expected_error_message = "Unknown strategy 'other'. Available options are 'mtime' and 'digest'."
      allow(Shakapacker.config).to receive(:compiler_strategy).and_return("other")

      expect { Shakapacker::CompilerStrategy.from_config(Shakapacker.instance) }.to raise_error(expected_error_message)
    end

    it "uses the given instance's config, not the global config" do
      custom_instance = Shakapacker::Instance.new
      allow(custom_instance.config).to receive(:compiler_strategy).and_return("mtime")
      allow(Shakapacker.config).to receive(:compiler_strategy).and_return("digest")

      strategy = Shakapacker::CompilerStrategy.from_config(custom_instance)
      expect(strategy).to be_an_instance_of(Shakapacker::MtimeStrategy)
    end
  end
end
