require "digest/sha1"
require "shakapacker/base_strategy"

module Shakapacker
  class DigestStrategy < BaseStrategy
    # Returns true if all the compiled packs are up to date with the underlying asset files.
    def fresh?
      last_compilation_digest&.== watched_files_digest
    end

    # Returns true if the compiled packs are out of date with the underlying asset files.
    def stale?
      !fresh?
    end

    def after_compile_hook
      # We used to only record the digest on success
      # However, the output file is still written on error, meaning that the digest should still be updated.
      # If it's not, you can end up in a situation where a recompile doesn't take place when it should.
      # See https://github.com/rails/webpacker/issues/2113
      record_compilation_digest
    end

    private

      def last_compilation_digest
        compilation_digest_path.read if compilation_digest_path.exist? && config.manifest_path.exist?
      rescue Errno::ENOENT, Errno::ENOTDIR
      end

      def watched_files_digest
        if Rails.env.development?
          warn <<~MSG.strip
          Shakapacker::Compiler - Slow setup for development
          Prepare JS assets with either:
          1. Running `bin/shakapacker-dev-server`
          2. Set `compile` to false in shakapacker.yml and run `bin/shakapacker -w`
        MSG
        end

        root_path = Pathname.new(File.expand_path(config.root_path))
        expanded_paths = [*default_watched_paths].map do |path|
          root_path.join(path)
        end
        files = Dir[*expanded_paths].reject { |f| File.directory?(f) }
        file_ids = files.sort.map { |f| "#{File.basename(f)}/#{Digest::SHA1.file(f).hexdigest}" }
        Digest::SHA1.hexdigest(file_ids.join("/"))
      end

      def record_compilation_digest
        config.cache_path.mkpath
        compilation_digest_path.write(watched_files_digest)
      end

      def compilation_digest_path
        path = "last-compilation-digest-#{Shakapacker.env}"
        path += "-#{generate_host_hash}" if generate_host_hash.present?

        config.cache_path.join(path)
      end

      def generate_host_hash
        # Using hash for memoizing the host hash is to make testing easier.
        # The default value, prevents generating hash in the situation where no value for asset_host
        # and SHAKAPACKER_ASSET_HOST are provided, leading to not add hash to the asset path.
        @generated_host_hashes ||= { [nil, nil] => "" }

        keys = [Rails.application.config.asset_host, ENV["SHAKAPACKER_ASSET_HOST"]]

        @generated_host_hashes[keys] ||= Digest::SHA1.hexdigest(keys.join("-"))
      end
  end
end
