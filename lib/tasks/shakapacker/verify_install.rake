namespace :shakapacker do
  desc "Verifies if Shakapacker is installed"
  task verify_install: [:verify_config, :check_node, :check_yarn, :check_binstubs]
end
