require_relative "spec_helper_initializer"

describe "EngineRakeTasks" do
  before :context do
    remove_webpack_binstubs
  end

  after :context do
    remove_webpack_binstubs
  end

  NODE_PACKAGE_MANAGERS.each do |fallback_manager|
    context "when using package_json with #{fallback_manager} as the manager" do
      with_use_package_json_gem(enabled: true, fallback_manager: fallback_manager)

      it "mounts app:shakapacker task successfully" do
        output = Dir.chdir(mounted_app_path) { `rake -T` }

        expect(output).to include "app:shakapacker"
      end

      it "only adds expected files to bin directory when binstubs is run" do
        Dir.chdir(mounted_app_path) { `bundle exec rake app:shakapacker:binstubs` }
        expected_binstub_paths.each { |path| expect(File.exist?(path)).to be true }
      end
    end
  end

  context "when not using package_json" do
    with_use_package_json_gem(enabled: false)

    it "mounts app:shakapacker task successfully" do
      output = Dir.chdir(mounted_app_path) { `rake -T` }

      expect(output).to include "app:shakapacker"
    end

    it "only adds expected files to bin directory when binstubs is run" do
      Dir.chdir(mounted_app_path) { `bundle exec rake app:shakapacker:binstubs` }
      expected_binstub_paths.each { |path| expect(File.exist?(path)).to be true }
    end
  end

  private
    def mounted_app_path
      File.expand_path("../mounted_app", __dir__)
    end

    def current_files_in_bin
      Dir.glob("#{mounted_app_path}/test/dummy/bin/*")
    end

    def expected_binstub_paths
      gem_path = File.expand_path("../..", __dir__)
      Dir.chdir("#{gem_path}/lib/install/bin") do
        Dir.glob("*").map { |file| "#{mounted_app_path}/test/dummy/bin/#{file}" }
      end
    end

    def remove_webpack_binstubs
      expected_binstub_paths.each do |path|
        File.delete(path) if File.exist?(path)
      end
    end
end
