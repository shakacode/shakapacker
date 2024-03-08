NODE_PACKAGE_MANAGERS = ["npm", "yarn_classic", "yarn_berry", "pnpm", "bun"]

def with_use_package_json_gem(fallback_manager)
  around do |example|
    old_package_json_fallback_manager_value = ENV["PACKAGE_JSON_FALLBACK_MANAGER"]

    ENV["PACKAGE_JSON_FALLBACK_MANAGER"] = fallback_manager.to_s

    example.run

    ENV["PACKAGE_JSON_FALLBACK_MANAGER"] = old_package_json_fallback_manager_value
  end
end
