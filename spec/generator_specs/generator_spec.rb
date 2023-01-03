require "pathname"

describe "Generator" do
  let(:base_rails_app_root_path) { "base-rails-app" }
  let(:gem_root) { "../.." }

  before :all do
    # install shakapacker from the current local project
    # run `rails webpacker:install`

    # allow($stdin).to receive(:gets).and_return('y')

    # Dir.chdir("base-rails-app") do
    #   puts "Running `bundle install`"
    #   `bundle install`
    #   puts "Running `bundle exec rails webpacker:install`"
    #   `bundle exec rails webpacker:install`
    #   $stdin = STDIN
    # end
  end

  it "creates webpacker.yml" do
    the_file = "config/webpacker.yml"
    actual_content, expected_content = fetch_content(the_file)
    puts original_path
    expect(actual_content).to eq expected_content
  end

  pending "updates package.json"

  it "creates config directory and its files" do
    expected_files = [
      "webpack.config.js"
    ]

    Dir.chdir(the_path("config/webpack")) do
      exisiting_files_in_config_webpack_dir = Dir.glob("*")
      expect(exisiting_files_in_config_webpack_dir).to eq expected_files
    end
  end

  it "adds binstubs" do
    expected_binstubs = []
    Dir.chdir(File.join(gem_root, "lib/install")) do
      expected_binstubs = Dir.glob("bin/*")
    end

    Dir.chdir(the_path) do
      actual_binstubs = Dir.glob("*")
      expect(actual_binstubs).to include(*expected_binstubs)
      pending "Check the content of binstubs as well"
    end
  end

  pending "modifies .gitignore"
  pending 'adds <%= javascript_pack_tag "application" %> or gives message if the file is missing'
  pending "updates `bin/setup"
  pending "updates CSP file. NOTICE: the very existance of this step is under question!"
  pending "installs relevant shakapacker version depending on webpacker version,"
  pending "installs peerdependencies"
  pending "it reports to the user if Webpacker installation failed"

  private
    def the_path(relative_path = nil)
      Pathname.new(File.join([base_rails_app_root_path, relative_path].compact))
    end

    def original_path(relative_path = nil)
      Pathname.new(File.join([gem_root, "lib/install" , relative_path].compact))
    end

    def fetch_content(the_file)
      file_path = the_path(the_file)
      original_file_path = original_path(the_file)
      actual_content = File.read(file_path)
      expected_content = File.read(original_file_path)

      [actual_content, expected_content]
    end

    def setup_project
      Dir.chdir(base_rails_app_root_path) do
        `bundle install`
        `bundle exec rails webpacker:install`
        $stdin = STDIN
      end
    end
end
