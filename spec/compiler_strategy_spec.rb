describe "CompilerStrategy" do
  it "can instantiate MtimeStrategy based on the config file" do
    allow(Webpacker.config).to receive(:compiler_strategy).and_return("mtime")
    expect(Webpacker::CompilerStrategy.from_config).to be_an_instance_of(Webpacker::MtimeStrategy)
  end

  it "can instantiate DigestStrategy based on the config file" do
    allow(Webpacker.config).to receive(:compiler_strategy).and_return("digest")
    expect(Webpacker::CompilerStrategy.from_config).to be_an_instance_of(Webpacker::DigestStrategy)
  end

  it "raise exception for unknown compiler_strategy in the config file" do
    expected_error_message = "Unknown strategy 'other'. Available options are 'mtime' and 'digest'."
    allow(Webpacker.config).to receive(:compiler_strategy).and_return("other")

    expect { Webpacker::CompilerStrategy.from_config }.to raise_error(expected_error_message)
  end
end
