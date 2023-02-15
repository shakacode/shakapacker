RSpec.describe "Env" do
  it "uses the same env for Rails and Shakapacker" do
    expect(Shakapacker.env).to eq Rails.env
  end

  it "uses production env without config" do
    with_rails_env("foo") do
      expect(Shakapacker.env).to eq "production"
    end
  end

  it "uses the given env in custom config" do
    with_rails_env("staging") do
      expect(Shakapacker.env).to eq "staging"
    end
  end

  it "uses 'production' as default env" do
    expect(Shakapacker::DEFAULT_ENV).to eq "production"
  end
end
