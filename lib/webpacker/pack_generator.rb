require "webpacker/configuration"
require 'pathname'

class Webpacker::PackGenerator

  attr_reader :component_file

  def initialize(component_file)
    @component_file = component_file
    create_generated_directory
    write_pack_file
  end

  def write_pack_file
    output_path = "#{generated_path}/#{file_name}.jsx"

    f = File.new(output_path, "w")
    f.puts(ror_import_statements)
    f.puts(component_import_statement)
    f.puts(register_component_statement)
    f.close
    puts "Generated: #{output_path}"
  end

  def ror_import_statements
    "import ReactOnRails from 'react-on-rails';\n"
  end

  def component_import_statement
    "import #{file_name} from '#{relative_component_path}';\n\n"
  end

  def register_component_statement
    "ReactOnRails.register({#{file_name}});"
  end

  def create_generated_directory
    Dir.mkdir(generated_path) unless  File.exist?(generated_path)
  end

  def relative_component_path
    generated = Pathname.new generated_path
    component = Pathname.new component_file.path
    relative_path = component.relative_path_from generated

    # Remove the File Extension from Import Statement
    relative_path.to_s.gsub(File.extname(component_file), "")
  end

  def generated_path
    "#{Webpacker.config.source_entry_path}/generated/"
  end

  def file_name
    File.basename(@component_file, ".*")
  end
end
