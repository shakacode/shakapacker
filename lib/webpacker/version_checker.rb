# frozen_string_literal: true
require "webpacker/version"

module Webpacker
  class VersionChecker
    attr_reader :node_package_version

    MAJOR_MINOR_PATCH_VERSION_REGEX = /(\d+)\.(\d+)\.(\d+)/.freeze

    def self.build
      new(NodePackageVersion.build)
    end

    def initialize(node_package_version)
      @node_package_version = node_package_version
    end

    def raise_if_gem_and_node_package_versions_differ
      # Skip check if package is not in package.json or listed from relative path, git repo or github URL
      return if node_package_version.skip_processing?

      node_major_minor_patch = node_package_version.major_minor_patch
      gem_major_minor_patch = gem_major_minor_patch_version
      versions_match = node_major_minor_patch[0] == gem_major_minor_patch[0] &&
                       node_major_minor_patch[1] == gem_major_minor_patch[1] &&
                       node_major_minor_patch[2] == gem_major_minor_patch[2]

      raise_differing_versions_warning unless versions_match

      raise_node_semver_version_warning if node_package_version.semver_wildcard?
    end

    private

      def common_error_msg
        <<-MSG.strip_heredoc
         Detected: #{node_package_version.raw}
              gem: #{gem_version}
         Ensure the installed version of the gem is the same as the version of
         your installed node package. Do not use >= or ~> in your Gemfile for shakapacker.
         Do not use ^ or ~ in your package.json for shakapacker.
         Run `yarn add shakapacker --exact` in the directory containing folder node_modules.
      MSG
      end

      def raise_differing_versions_warning
        msg = "**ERROR** Webpacker: Webpacker gem and node package versions do not match\n#{common_error_msg}"
        raise msg
      end

      def raise_node_semver_version_warning
        msg = "**ERROR** Webpacker: Your node package version for shakapacker contains a "\
              "^ or ~\n#{common_error_msg}"
        raise msg
      end

      def gem_version
        Webpacker::VERSION
      end

      def gem_major_minor_patch_version
        match = gem_version.match(MAJOR_MINOR_PATCH_VERSION_REGEX)
        [match[1], match[2], match[3]]
      end

      class NodePackageVersion
        attr_reader :package_json

        def self.build
          new(package_json_path)
        end

        def self.package_json_path
          Rails.root.join("package.json")
        end

        def initialize(package_json)
          @package_json = package_json
        end

        def raw
          parsed_package_contents = JSON.parse(package_json_contents)
          parsed_package_contents.dig("dependencies", "shakapacker").to_s
        end

        def semver_wildcard?
          raw.match(/[~^]/).present?
        end

        def skip_processing?
          !package_specified? || relative_path? || git_url? || github_url?
        end

        def major_minor_patch
          return if skip_processing?

          match = raw.match(MAJOR_MINOR_PATCH_VERSION_REGEX)
          unless match
            raise "Cannot parse version number '#{raw}' (wildcard versions are not supported)"
          end

          [match[1], match[2], match[3]]
        end

        private

          def package_specified?
            raw.present?
          end

          def relative_path?
            raw.match(%r{(\.\.|\Afile:///)}).present?
          end

          def git_url?
            raw.match(%r{^git}).present?
          end

          def github_url?
            raw.match(%r{^([\w-]+\/[\w-]+)}).present?
          end

          def package_json_contents
            @package_json_contents ||= File.read(package_json)
          end
      end
  end
end
