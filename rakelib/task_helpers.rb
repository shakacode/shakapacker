# frozen_string_literal: true

module Shakapacker
  module TaskHelpers
    extend Forwardable

    def_delegators 'Shakapacker::Utils::Misc', :sh_in_dir

    # Returns the root folder of the shakapacker gem
    def gem_root
      File.expand_path("..", __dir__)
    end

    # Returns the folder where examples are located
    def examples_dir
      File.join(gem_root, "gen-examples", "examples")
    end

    def dummy_app_dir
      File.join(gem_root, "spec/dummy")
    end

    def bundle_install_in(dir)
      unbundled_sh_in_dir(dir, "bundle install")
    end

    # Runs bundle exec using that directory's Gemfile
    def bundle_exec(dir: nil, args: nil, env_vars: "")
      sh_in_dir(dir, "#{env_vars} #{args}")
    end

    def generators_source_dir
      File.join(gem_root, "lib/generators/shakapacker")
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) do |(key, value), new_hash|
        new_key = key.is_a?(String) ? key.to_sym : key
        new_value = value.is_a?(Hash) ? symbolize_keys(value) : value
        new_hash[new_key] = new_value
      end
    end
  end
end
