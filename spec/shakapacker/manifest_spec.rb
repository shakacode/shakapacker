require_relative "spec_helper_initializer"

describe "Shakapacker::Manifest" do
  let(:manifest_path) { File.expand_path File.join(File.dirname(__FILE__), "./test_app/public/packs", "manifest.json").to_s }

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
