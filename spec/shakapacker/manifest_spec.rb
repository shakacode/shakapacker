require_relative "spec_helper_initializer"

describe "Shakapacker::Manifest" do
  let(:manifest_path) { File.expand_path File.join(File.dirname(__FILE__), "./test_app/public/packs", "manifest.json").to_s }

  context "when manifest file exists but is empty" do
    it "#lookup! raises an error indicating the bundler is still compiling" do
      allow(Shakapacker.config).to receive(:compile?).and_return(false)
      allow(Shakapacker.manifest).to receive(:data).and_return({})
      allow(Shakapacker.config.manifest_path).to receive(:exist?).and_return(true)

      expect {
        Shakapacker.manifest.lookup!("application.js")
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /manifest is empty.*still compiling/i)
    end

    it "#lookup_pack_with_chunks! raises an error indicating the bundler is still compiling" do
      allow(Shakapacker.config).to receive(:compile?).and_return(false)
      allow(Shakapacker.manifest).to receive(:data).and_return({})
      allow(Shakapacker.config.manifest_path).to receive(:exist?).and_return(true)

      expect {
        Shakapacker.manifest.lookup_pack_with_chunks!("application", type: :javascript)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /manifest is empty.*still compiling/i)
    end
  end

  context "when manifest file does not exist" do
    let(:fake_manifest_path) { instance_double(Pathname, exist?: false, to_s: "/fake/manifest.json") }

    it "#lookup! raises an error indicating the manifest file is not found" do
      allow(Shakapacker.config).to receive(:compile?).and_return(false)
      allow(Shakapacker.manifest).to receive(:data).and_return({})
      allow(Shakapacker.config).to receive(:manifest_path).and_return(fake_manifest_path)

      expect {
        Shakapacker.manifest.lookup!("application.js")
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /manifest file not found.*has not yet built/i)
    end

    it "#lookup_pack_with_chunks! raises an error indicating the manifest file is not found" do
      allow(Shakapacker.config).to receive(:compile?).and_return(false)
      allow(Shakapacker.manifest).to receive(:data).and_return({})
      allow(Shakapacker.config).to receive(:manifest_path).and_return(fake_manifest_path)

      expect {
        Shakapacker.manifest.lookup_pack_with_chunks!("application", type: :javascript)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /manifest file not found.*has not yet built/i)
    end
  end

  context "with no integrity hashes" do
    it "#lookup! raises an exception for a non-existing asset file" do
      asset_file = "calendar.js"
      expected_error_message = "Shakapacker can't find #{asset_file} in #{manifest_path}"

      allow(Shakapacker.config).to receive(:compile?).and_return(false)

      expect {
        Shakapacker.manifest.lookup!(asset_file)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /#{expected_error_message}/)
    end

    it "#lookup! raises an exception for a non-existing asset file with type and without an extension" do
      asset_file = "calendar"
      expected_error_message = "Shakapacker can't find #{asset_file}.js in #{manifest_path}"

      allow(Shakapacker.config).to receive(:compile?).and_return(false)

      expect {
        Shakapacker.manifest.lookup!(asset_file, type: :javascript)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /#{expected_error_message}/)
    end

    it "#lookup! returns the path to the bundled bootstrap.js" do
      actual = Shakapacker.manifest.lookup!("bootstrap.js")
      expected = "/packs/bootstrap-300631c4f0e0f9c865bc.js"

      expect(actual).to eq expected
    end

    it "#lookup_pack_with_chunks! returns an array of paths to the bundled bootstrap of type javascript" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("bootstrap", type: :javascript)
      expected = ["/packs/bootstrap-300631c4f0e0f9c865bc.js"]

      expect(actual).to eq expected
    end

    it "#lookup_with_chunks! returns an array of paths to the bundled bootstrap.js of type javascript" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("bootstrap.js", type: :javascript)
      expected = ["/packs/bootstrap-300631c4f0e0f9c865bc.js"]

      expect(actual).to eq expected
    end

    it "#lookup_with_chunks! returns an array of paths to the bundled 'print/application' without an extension and in a sub-directory" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("print/application", type: :css)
      expected = ["/packs/print/application-983b6c164a47f7ed49cd.css"]

      expect(actual).to eq expected
    end

    it "#lookup_with_chunks! returns an array of paths to the bundled 'print/application.css' in a sub-directory" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("print/application.css", type: :css)
      expected = ["/packs/print/application-983b6c164a47f7ed49cd.css"]

      expect(actual).to eq expected
    end

    it "#lookup returns nil for non-existing asset files" do
      expect(Shakapacker.manifest.lookup("foo.js")).to be nil
    end

    it "#lookup_pack_with_chunks returns nil for non-existing asset files" do
      expect(Shakapacker.manifest.lookup_pack_with_chunks("foo.js")).to be nil
    end

    it "#lookup returns the path for bootstrap.js" do
      actual = Shakapacker.manifest.lookup("bootstrap.js")
      expected = "/packs/bootstrap-300631c4f0e0f9c865bc.js"

      expect(actual).to eq expected
    end

    it "#lookup_pack_with_chunks! raises an exception for non-existing asset files" do
      asset_file = "calendar"

      expected_error_message = "Shakapacker can't find #{asset_file}.js in #{manifest_path}"

      allow(Shakapacker.config).to receive(:compile?).and_return(false)

      expect {
        Shakapacker.manifest.lookup_pack_with_chunks!(asset_file, type: :javascript)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /#{expected_error_message}/)
    end

    it "#lookup_pack_with_chunks! returns an array of paths to bundled js files with 'application' in their name" do
      actual_application_entrypoints = Shakapacker.manifest.lookup_pack_with_chunks!("application", type: :javascript)
      expected_application_entrypoints = [
        "/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js",
        "/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js",
        "/packs/application-k344a6d59eef8632c9d1.js"
      ]

      expect(actual_application_entrypoints).to eq expected_application_entrypoints
    end
  end

  context "with integrity hashes" do
    it "#lookup! raises an exception for a non-existing asset file" do
      asset_file = "calendar_with_integrity.js"
      expected_error_message = "Shakapacker can't find #{asset_file} in #{manifest_path}"

      allow(Shakapacker.config).to receive(:compile?).and_return(false)

      expect {
        Shakapacker.manifest.lookup!(asset_file)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /#{expected_error_message}/)
    end

    it "#lookup! raises an exception for a non-existing asset file with type and without an extension" do
      asset_file = "calendar_with_integrity"
      expected_error_message = "Shakapacker can't find #{asset_file}.js in #{manifest_path}"

      allow(Shakapacker.config).to receive(:compile?).and_return(false)

      expect {
        Shakapacker.manifest.lookup!(asset_file, type: :javascript)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /#{expected_error_message}/)
    end

    it "#lookup! returns the path to the bundled bootstrap_with_integrity.js" do
      actual = Shakapacker.manifest.lookup!("bootstrap_with_integrity.js")
      expected = "/packs/bootstrap_with_integrity-300631c4f0e0f9c865bc.js"

      expect(actual).to eq expected
    end

    it "#lookup_pack_with_chunks! returns an array of paths to the bundled bootstrap_with_integrity of type javascript" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("bootstrap_with_integrity", type: :javascript)
      expected = [{ "src" => "/packs/bootstrap-300631c4f0e0f9c865bc.js", "integrity" => "sha384-hash" }]

      expect(actual).to eq expected
    end

    it "#lookup_with_chunks! returns an array of paths to the bundled bootstrap_with_integrity.js of type javascript" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("bootstrap_with_integrity.js", type: :javascript)
      expected = [{ "src" => "/packs/bootstrap-300631c4f0e0f9c865bc.js", "integrity" => "sha384-hash" }]

      expect(actual).to eq expected
    end

    it "#lookup_with_chunks! returns an array of paths to the bundled 'print/application_with_integrity' without an extension and in a sub-directory" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("print/application_with_integrity", type: :css)
      expected = [{ "src" => "/packs/print/application-983b6c164a47f7ed49cd.css", "integrity" => "sha384-hash" }]

      expect(actual).to eq expected
    end

    it "#lookup_with_chunks! returns an array of paths to the bundled 'print/application_with_integrity.css' in a sub-directory" do
      actual = Shakapacker.manifest.lookup_pack_with_chunks!("print/application_with_integrity.css", type: :css)
      expected = [{ "src" => "/packs/print/application-983b6c164a47f7ed49cd.css", "integrity" => "sha384-hash" }]

      expect(actual).to eq expected
    end

    it "#lookup returns nil for non-existing asset files" do
      expect(Shakapacker.manifest.lookup("foo_with_integrity.js")).to be nil
    end

    it "#lookup_pack_with_chunks returns nil for non-existing asset files" do
      expect(Shakapacker.manifest.lookup_pack_with_chunks("foo_with_integrity.js")).to be nil
    end

    it "#lookup returns the path for bootstrap_with_integrity.js" do
      actual = Shakapacker.manifest.lookup("bootstrap_with_integrity.js")
      expected = "/packs/bootstrap_with_integrity-300631c4f0e0f9c865bc.js"

      expect(actual).to eq expected
    end

    it "#lookup_pack_with_chunks! raises an exception for non-existing asset files" do
      asset_file = "calendar_with_integrity"

      expected_error_message = "Shakapacker can't find #{asset_file}.js in #{manifest_path}"

      allow(Shakapacker.config).to receive(:compile?).and_return(false)

      expect {
        Shakapacker.manifest.lookup_pack_with_chunks!(asset_file, type: :javascript)
      }.to raise_error(Shakapacker::Manifest::MissingEntryError, /#{expected_error_message}/)
    end

    it "#lookup_pack_with_chunks! returns an array of paths to bundled js files with 'application_with_integrity' in their name" do
      actual_application_entrypoints = Shakapacker.manifest.lookup_pack_with_chunks!("application_with_integrity", type: :javascript)
      expected_application_entrypoints = [
        {
          "src" => "/packs/vendors~application~bootstrap-c20632e7baf2c81200d3.chunk.js",
          "integrity" => "sha384-hash",
        },
        {
          "src" => "/packs/vendors~application-e55f2aae30c07fb6d82a.chunk.js",
          "integrity" => "sha384-hash"
        },
        {
          "src" => "/packs/application-k344a6d59eef8632c9d1.js",
          "integrity" => "sha384-hash"
        }
      ]

      expect(actual_application_entrypoints).to eq expected_application_entrypoints
    end
  end
end
