# frozen_string_literal: true

require_relative "../../webpacker/version"

module Shakapacker
  module Utils
    class VersionSyntaxConverter
      def rubygem_to_npm(rubygem_version = Webpacker::VERSION)
        regex_match = rubygem_version.match(/(\d+\.\d+\.\d+)[.\-]?(.+)?/)
        return "#{regex_match[1]}-#{regex_match[2]}" if regex_match[2]

        regex_match[1].to_s
      end

      def npm_to_rubygem(npm_version)
        match = npm_version
                  .tr("-", ".")
                  .strip
                  .match(/(\d.*)/)
        match.present? ? match[0] : nil
      end
    end
  end
end
