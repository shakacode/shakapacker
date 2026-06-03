require "spec_helper"

# The installer rewrites these literal values in the bundled config template via
# gsub_file (see lib/install/template.rb). gsub_file silently no-ops when the
# literal is absent, so if the shipped template is ever reformatted (quote style,
# spacing, or default value) the installer would quietly stop honoring the chosen
# bundler/transpiler. These guards fail fast at CI time if that contract breaks.
describe "bundled install config template" do
  let(:config_path) { File.expand_path("../../lib/install/config/shakapacker.yml", __dir__) }
  let(:contents) { File.read(config_path) }

  it 'ships assets_bundler: "webpack" so the bundler gsub_file matches' do
    expect(contents).to include('assets_bundler: "webpack"')
  end

  it 'ships javascript_transpiler: "swc" so the transpiler gsub_file matches' do
    expect(contents).to include('javascript_transpiler: "swc"')
  end
end
