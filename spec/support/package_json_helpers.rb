NODE_PACKAGE_MANAGERS = ["npm", "yarn_classic", "yarn_berry", "pnpm", "bun"]

def with_use_package_json_gem(enabled:, fallback_manager: nil)
  around do |example|
    old_use_package_json_gem_value = ENV["SHAKAPACKER_USE_PACKAGE_JSON_GEM"]
    old_package_json_fallback_manager_value = ENV["PACKAGE_JSON_FALLBACK_MANAGER"]

    ENV["SHAKAPACKER_USE_PACKAGE_JSON_GEM"] = enabled.to_s
    ENV["PACKAGE_JSON_FALLBACK_MANAGER"] = fallback_manager.to_s

    example.run

    ENV["SHAKAPACKER_USE_PACKAGE_JSON_GEM"] = old_use_package_json_gem_value
    ENV["PACKAGE_JSON_FALLBACK_MANAGER"] = old_package_json_fallback_manager_value
  end
end
