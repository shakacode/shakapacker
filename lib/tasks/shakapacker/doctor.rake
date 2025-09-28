require "shakapacker/doctor"

namespace :shakapacker do
  desc "Checks for common Shakapacker configuration issues and missing dependencies"
  task doctor: :environment do
    Shakapacker::Doctor.new.run
  end
end
