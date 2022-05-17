require "webpacker/configuration"
require "webpacker/pack_generator"

namespace :webpacker do
  desc "Generates packs directory for all components in components_path"
  task :generate_packs do
    if Webpacker.config.components_path.exist?
      path = Webpacker.config.components_path
      components_directory_name = Webpacker.config.components_directory_name
      files = Dir.glob("#{path}/**/#{components_directory_name}/*")

      files.each do |file|
        registered_component_file = File.open(file)

        Webpacker::PackGenerator.new(registered_component_file)
      end
    else
      puts "components_path is not defined in configuration"
    end
  end

  def import_line?(line)
    line.contains "import"
  end

end
