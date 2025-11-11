require "shakapacker/bundler_switcher"

namespace :shakapacker do
  desc <<~DESC
    Switch between webpack and rspack bundlers

    Easily switch your Shakapacker configuration between webpack and rspack bundlers.
    This task updates config/shakapacker.yml and optionally manages npm dependencies.

    Usage:
      rake shakapacker:switch_bundler [webpack|rspack] -- [OPTIONS]

    Options:
      --install-deps    Automatically install/uninstall bundler dependencies
      --no-uninstall    Skip uninstalling old bundler packages (faster, keeps both bundlers)
      --init-config     Create custom dependencies configuration file
      --help, -h        Show detailed help message

    Examples:
      # Switch to rspack with automatic dependency management
      rake shakapacker:switch_bundler rspack -- --install-deps

      # Fast switching without uninstalling (keeps both bundlers)
      rake shakapacker:switch_bundler rspack -- --install-deps --no-uninstall

      # Switch to rspack (manual dependency management)
      rake shakapacker:switch_bundler rspack

      # Switch back to webpack with dependency management
      rake shakapacker:switch_bundler webpack -- --install-deps

      # Create custom dependencies config file
      rake shakapacker:switch_bundler -- --init-config

      # Show current bundler and usage help
      rake shakapacker:switch_bundler -- --help

    Note: When using 'rake', you must use '--' to separate rake options from task arguments.

    What it does:
      - Updates 'assets_bundler' in config/shakapacker.yml
      - Preserves YAML comments and structure
      - Updates 'javascript_transpiler' to 'swc' when switching to rspack
      - With --install-deps: installs/uninstalls npm dependencies automatically
      - Without --install-deps: shows manual installation commands

    Custom Dependencies:
      Create .shakapacker-switch-bundler-dependencies.yml to customize which
      npm packages are installed/uninstalled during bundler switching.

    See docs/rspack_migration_guide.md for more information.
  DESC
  task :switch_bundler do
    switcher = Shakapacker::BundlerSwitcher.new

    if ARGV.empty? || ARGV.include?("--help") || ARGV.include?("-h")
      switcher.show_usage
    elsif ARGV.include?("--init-config")
      switcher.init_config
    else
      bundler = ARGV[1]
      install_deps = ARGV.include?("--install-deps")
      no_uninstall = ARGV.include?("--no-uninstall")

      if bundler.nil? || bundler.start_with?("-")
        switcher.show_usage
      else
        switcher.switch_to(bundler, install_deps: install_deps, no_uninstall: no_uninstall)
      end
    end

    # Prevent rake from trying to execute arguments as tasks
    ARGV.each { |arg| task arg.to_sym {} }
  end
end
