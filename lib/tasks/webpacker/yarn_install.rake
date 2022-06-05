namespace :webpacker do
  desc "Support for older Rails versions. Install all JavaScript dependencies as specified via Yarn"
  task :yarn_install do
    warn <<~MSG.strip
      Shakapacker - Automatic installation of yarn packages is deprecated
      Automatic installation of yarn packages when assets are precompiled is deprecated and will be removed in Shakapacker v7.
      Please ensure you are installing yarn packages explicitly before the asset compilation.
    MSG

    valid_node_envs = %w[test development production]
    node_env = ENV.fetch("NODE_ENV") do
      valid_node_envs.include?(Rails.env) ? Rails.env : "production"
    end
    Dir.chdir(Rails.root) do
      yarn_flags =
        if `yarn --version`.start_with?("1")
          "--no-progress --frozen-lockfile"
        else
          "--immutable"
        end
      system({ "NODE_ENV" => node_env }, "yarn install #{yarn_flags}")
    end
  end
end
