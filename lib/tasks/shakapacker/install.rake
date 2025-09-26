install_template_path = File.expand_path("../../install/template.rb", __dir__).freeze
bin_path = ENV["BUNDLE_BIN"] || Rails.root.join("bin")

namespace :shakapacker do
  desc "Install Shakapacker in this application (use ASSETS_BUNDLER=rspack for Rspack)"
  task :install, [:bundler] => [:check_node] do |task, args|
    Shakapacker::Configuration.installing = true

    if args[:bundler] == "rspack" || ENV["ASSETS_BUNDLER"] == "rspack"
      ENV["SHAKAPACKER_ASSET_BUNDLER"] = "rspack"
    end

    prefix = task.name.split(/#|shakapacker:install/).first

    if Rails::VERSION::MAJOR >= 5
      exec "#{RbConfig.ruby} '#{bin_path}/rails' #{prefix}app:template LOCATION='#{install_template_path}'"
    else
      exec "#{RbConfig.ruby} '#{bin_path}/rake' #{prefix}rails:template LOCATION='#{install_template_path}'"
    end
  end
end
