require_relative "spec_helper_initializer"

RSpec.describe "Webpacker.env" do
  it "uses the same env for Rails and Webpacker" do
    expect(Webpacker.env).to eq Rails.env
  end

  it "uses production env without config" do
    with_rails_env("foo") do
      expect(Webpacker.env).to eq "production"
    end
  end

  it "uses the given env in custom config" do
    with_rails_env("staging") do
      expect(Webpacker.env).to eq "staging"
    end
  end

  it "uses 'production' as default env" do
    expect(Webpacker::DEFAULT_ENV).to eq "production"
  end
end
