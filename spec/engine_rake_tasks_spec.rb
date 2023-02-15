describe "EngineRakeTasks" do
  before :context do
    remove_webpack_binstubs
  end

  after :context do
    remove_webpack_binstubs
  end

  it "mounts app:webpacker task successfully" do
    output = Dir.chdir(mounted_app_path) { `rake -T` }
    expect(output).to include "app:webpacker"
  end

  it "binstubs adds only expected files to bin directory" do
    original_files_in_bin = current_files_in_bin

    Dir.chdir(mounted_app_path) { `bundle exec rake app:webpacker:binstubs` }
    webpack_binstub_paths.each { |path| expect(File.exist?(path)).to be true }

    # and no other files are added
    expect(current_files_in_bin - webpack_binstub_paths).to match_array original_files_in_bin
  end

  private
    def mounted_app_path
      File.expand_path("mounted_app", __dir__)
    end

    def current_files_in_bin
      Dir.glob("#{mounted_app_path}/test/dummy/bin/*")
    end

    def webpack_binstub_paths
      [
        "#{mounted_app_path}/test/dummy/bin/yarn",
        "#{mounted_app_path}/test/dummy/bin/shakapacker",
        "#{mounted_app_path}/test/dummy/bin/shakapacker-dev-server",
      ]
    end

    def remove_webpack_binstubs
      webpack_binstub_paths.each do |path|
        File.delete(path) if File.exist?(path)
      end
    end
end
