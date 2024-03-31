NODE_PACKAGE_MANAGERS = ["npm", "yarn_classic", "yarn_berry", "pnpm", "bun"]

def with_package_json_fallback_manager(fallback_manager)
  around do |example|
    old_package_json_fallback_manager_value = ENV["PACKAGE_JSON_FALLBACK_MANAGER"]

    ENV["PACKAGE_JSON_FALLBACK_MANAGER"] = fallback_manager.to_s

    example.run

    ENV["PACKAGE_JSON_FALLBACK_MANAGER"] = old_package_json_fallback_manager_value
  end
end

def within_temp_directory(tmpdir = nil, &block)
  Dir.mktmpdir("shakapacker-", tmpdir) do |dir|
    Dir.chdir(dir, &block)
  end
end
