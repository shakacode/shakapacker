# frozen_string_literal: true

require "json"
require_relative "../rails_helper"

RSpec.describe "custom build manifest", type: :helper do
  let(:manifest_path) { Rails.root.join("public/packs/manifest.json") }
  let(:custom_config_path) { Rails.root.join("config/shakapacker-custom-build.yml") }
  let(:manifest) do
    {
      "custom-build.js" => "/packs/custom-build-123abc.js",
      "custom-build.css" => "/packs/custom-build-456def.css",
      "entrypoints" => {
        "custom-build" => {
          "assets" => {
            "js" => [
              "/packs/custom-build-runtime-999aaa.js",
              "/packs/custom-build-123abc.js"
            ],
            "css" => ["/packs/custom-build-456def.css"]
          }
        }
      }
    }
  end

  around do |example|
    original_config = ENV["SHAKAPACKER_CONFIG"]
    original_instance = Shakapacker.instance
    original_manifest = File.exist?(manifest_path) ? File.binread(manifest_path) : nil

    ENV["SHAKAPACKER_CONFIG"] = custom_config_path.to_s
    Shakapacker.instance = Shakapacker::Instance.new
    FileUtils.mkdir_p(manifest_path.dirname)
    File.write(manifest_path, JSON.pretty_generate(manifest))

    example.run
  ensure
    if original_manifest
      File.write(manifest_path, original_manifest)
    else
      FileUtils.rm_f(manifest_path)
    end

    Shakapacker.instance = original_instance
    ENV["SHAKAPACKER_CONFIG"] = original_config
  end

  it "reads helper tags from a non-Shakapacker manifest without compiling" do
    scripts = helper.javascript_pack_tag("custom-build", early_hints: false)
    styles = helper.stylesheet_pack_tag("custom-build", early_hints: false)

    expect(scripts).to include('src="/packs/custom-build-runtime-999aaa.js"')
    expect(scripts).to include('src="/packs/custom-build-123abc.js"')
    expect(styles).to include('href="/packs/custom-build-456def.css"')
    expect(helper.asset_pack_path("custom-build.js")).to eq(
      "/packs/custom-build-123abc.js"
    )
  end
end
