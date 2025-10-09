require "shakapacker/doctor"

namespace :shakapacker do
  desc "Checks for common Shakapacker configuration issues and missing dependencies"
  task doctor: :environment do
    # Parse command-line options
    options = {}
    ARGV.each do |arg|
      case arg
      when "--help", "-h"
        options[:help] = true
      when "--verbose", "-v"
        options[:verbose] = true
      end
    end

    Shakapacker::Doctor.new(nil, nil, options).run

    # Prevent rake from treating options as task names
    ARGV.each { |arg| task arg.to_sym do; end if arg.start_with?("--", "-") }
  end
end
