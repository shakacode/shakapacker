require_relative "spec_helper_initializer"

describe "Shakapacker::Utils" do
  describe ".parse_config_file_to_hash" do
    context "without passing config_path" do
      it "loads config from `config/shakapacker.yml`" do
        default_config_path = Rails.root.join("config/shakapacker.yml")

        expect(YAML).to receive(:load_file).with(default_config_path.to_s).and_return({})
        config = Shakapacker::Utils.parse_config_file_to_hash
      end

      it "returns hash based on `config/shakapacker.yml`" do
        config = Shakapacker::Utils.parse_config_file_to_hash

        expect(config).to match a_hash_including({
          default: a_hash_including({
            source_path: "app/javascript",
            source_entry_path: "entrypoints",
            nested_entries: false
          })
        })
      end
    end

    context "with valid config_path" do
      let(:config_path) { Rails.root.join("config/shakapacker_nested_entries.yml") }

      it "loads config from the given path" do
        expect(YAML).to receive(:load_file).with(config_path.to_s).and_return({})
        config = Shakapacker::Utils.parse_config_file_to_hash(config_path)
      end

      it "returns hash based on the given config file" do
        config = Shakapacker::Utils.parse_config_file_to_hash(config_path)

        expect(config).to match a_hash_including({
          default: a_hash_including({
            source_path: "app/javascript",
            source_entry_path: "entrypoints",
            nested_entries: true
          })
        })
      end
    end

    context "with invalid (or non-existing yet) config_path" do
      it "raises error" do
        config_path = "an_invalid_path.yml"
        expect {
          Shakapacker::Utils.parse_config_file_to_hash(config_path)
        }.to raise_error.with_message(/configuration file not found/)
      end

      it "returns empty hash while installing" do
        ENV["SHAKAPACKER_INSTALLING"] = "true"
        config_path = "the_missing_config_file_while_installing.yml"
        config = Shakapacker::Utils.parse_config_file_to_hash(config_path)

        expect(config).to match({})
      end
    end
  end
end
