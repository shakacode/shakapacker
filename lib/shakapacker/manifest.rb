# Manifest for looking up compiled asset paths
#
# The manifest reads the +manifest.json+ file produced by webpack/rspack during
# compilation and provides methods to look up the compiled (digested) paths for
# source files.
#
# This allows view helpers like +javascript_pack_tag+, +stylesheet_pack_tag+, and
# +asset_pack_path+ to take a reference to a source file (e.g., "calendar.js")
# and turn it into the compiled path with digest (e.g., "/packs/calendar-1016838bab065ae1e314.js").
#
# == Automatic Compilation
#
# When the configuration has +compile: true+ in shakapacker.yml, any lookups will
# automatically trigger compilation if the assets are stale. This is typically
# enabled in development and disabled in production.
#
# == Caching
#
# The manifest can cache the loaded data in memory when +cache_manifest: true+ is
# set in the configuration. This improves performance in production by avoiding
# repeated file reads.
#
# @example Looking up assets
#   manifest = Shakapacker.manifest
#   manifest.lookup("application.js")
#   #=> "/packs/application-abc123.js"
#
#   manifest.lookup!("missing.js")
#   #=> raises Shakapacker::Manifest::MissingEntryError
#
# @see Shakapacker::Helper
class Shakapacker::Manifest
  # Raised when an asset cannot be found in the manifest
  class MissingEntryError < StandardError; end

  delegate :config, :compiler, :dev_server, to: :@instance

  # Creates a new manifest instance
  #
  # @param instance [Shakapacker::Instance] the Shakapacker instance
  # @return [Shakapacker::Manifest] the new manifest
  def initialize(instance)
    @instance = instance
  end

  # Reloads the manifest data from disk
  #
  # Forces a fresh read of the manifest.json file, bypassing any cache.
  # This is useful when you know the manifest has been updated.
  #
  # @return [Hash] the loaded manifest data
  def refresh
    @data = load
  end

  # Looks up an entry point with all its chunks (split code)
  #
  # This method is used when you need to load all chunks for a pack that has
  # been split via code splitting. It returns an array of asset paths for the
  # main entry and all its dynamic imports.
  #
  # @param name [String] the entry point name (e.g., "application")
  # @param pack_type [Hash] options hash with :type key (:javascript, :stylesheet, etc.)
  # @return [Array<String>, nil] array of asset paths, or nil if not found
  # @example
  #   manifest.lookup_pack_with_chunks("application", type: :javascript)
  #   #=> ["/packs/runtime-abc123.js", "/packs/application-def456.js"]
  def lookup_pack_with_chunks(name, pack_type = {})
    compile if compiling?

    manifest_pack_type = manifest_type(pack_type[:type])
    manifest_pack_name = manifest_name(name, manifest_pack_type)
    find("entrypoints")[manifest_pack_name]["assets"][manifest_pack_type]
  rescue NoMethodError
    nil
  end

  # Like {#lookup_pack_with_chunks}, but raises an error if not found
  #
  # @param name [String] the entry point name
  # @param pack_type [Hash] options hash with :type key
  # @return [Array<String>] array of asset paths
  # @raise [MissingEntryError] if the entry point is not found in the manifest
  def lookup_pack_with_chunks!(name, pack_type = {})
    lookup_pack_with_chunks(name, pack_type) || handle_missing_entry(name, pack_type)
  end

  # Looks up the compiled path for a given asset
  #
  # Computes the relative path for a Shakapacker asset using the manifest.json file.
  # If automatic compilation is enabled and the assets are stale, triggers a
  # compilation before looking up the path.
  #
  # @param name [String] the source file name (e.g., "calendar.js" or "calendar")
  # @param pack_type [Hash] options hash with :type key (:javascript, :stylesheet, etc.).
  #   If not specified, the extension from the name is used.
  # @return [String, nil] the compiled asset path, or nil if not found
  # @example
  #   Shakapacker.manifest.lookup('calendar.js')
  #   #=> "/packs/calendar-1016838bab065ae1e122.js"
  #
  #   Shakapacker.manifest.lookup('calendar', type: :javascript)
  #   #=> "/packs/calendar-1016838bab065ae1e122.js"
  def lookup(name, pack_type = {})
    compile if compiling?

    find(full_pack_name(name, pack_type[:type]))
  end

  # Like {#lookup}, but raises an error if the asset is not found
  #
  # @param name [String] the source file name
  # @param pack_type [Hash] options hash with :type key
  # @return [String] the compiled asset path
  # @raise [MissingEntryError] if the asset is not found in the manifest
  # @example
  #   Shakapacker.manifest.lookup!('calendar.js')
  #   #=> "/packs/calendar-1016838bab065ae1e122.js"
  #
  #   Shakapacker.manifest.lookup!('missing.js')
  #   #=> raises MissingEntryError
  def lookup!(name, pack_type = {})
    lookup(name, pack_type) || handle_missing_entry(name, pack_type)
  end

  private
    def compiling?
      config.compile? && !dev_server.running?
    end

    def compile
      Shakapacker.logger.tagged("Shakapacker") { compiler.compile }
    end

    def data
      if config.cache_manifest?
        @data ||= load
      else
        refresh
      end
    end

    def find(name)
      return nil unless data[name.to_s].present?

      return data[name.to_s] unless data[name.to_s].respond_to?(:dig)

      # Try to return src, if that fails, (ex. entrypoints object) return the whole object.
      data[name.to_s].dig("src") || data[name.to_s]
    end

    def full_pack_name(name, pack_type)
      return name unless File.extname(name.to_s).empty?
      "#{name}.#{manifest_type(pack_type)}"
    end

    def handle_missing_entry(name, pack_type)
      raise Shakapacker::Manifest::MissingEntryError, missing_file_from_manifest_error(full_pack_name(name, pack_type[:type]))
    end

    def load
      if config.manifest_path.exist?
        JSON.parse config.manifest_path.read
      else
        {}
      end
    end

    # The `manifest_name` method strips of the file extension of the name, because in the
    # manifest hash the entrypoints are defined by their pack name without the extension.
    # When the user provides a name with a file extension, we want to try to strip it off.
    def manifest_name(name, pack_type)
      name.chomp(".#{pack_type}")
    end

    def manifest_type(pack_type)
      case pack_type
      when :javascript then "js"
      when :stylesheet then "css"
      else pack_type.to_s
      end
    end

    def missing_file_from_manifest_error(bundle_name)
      bundler_name = config.assets_bundler
      <<-MSG
Shakapacker can't find #{bundle_name} in #{config.manifest_path}. Possible causes:
1. You forgot to install javascript packages or are running an incompatible javascript runtime version
2. Your app has code with a non-standard extension (like a `.jsx` file) but the extension is not in the `extensions` config in `config/shakapacker.yml`
3. You have set compile: false (see `config/shakapacker.yml`) for this environment
   (unless you are using the `bin/shakapacker -w` or the `bin/shakapacker-dev-server`, in which case maybe you aren't running the dev server in the background?)
4. Your #{bundler_name} has not yet FINISHED running to reflect updates.
5. You have misconfigured Shakapacker's `config/shakapacker.yml` file.
6. Your #{bundler_name} configuration is not creating a manifest with the expected structure.
7. Ensure the 'assets_bundler' in config/shakapacker.yml is set correctly (currently: #{bundler_name}).

Your manifest contains:
#{JSON.pretty_generate(@data)}
      MSG
    end
end
