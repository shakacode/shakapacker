require "shakapacker/bundler_switcher"

namespace :shakapacker do
  desc <<~DESC
    Switch between webpack and rspack bundlers

    Easily switch your Shakapacker configuration between webpack and rspack bundlers.
    This task updates config/shakapacker.yml and optionally manages npm dependencies.

    Usage:
      # Using rake (with -- separator for options)
      rake shakapacker:switch_bundler [webpack|rspack] -- [OPTIONS]

      # Using rails (with environment variables)
      rails shakapacker:switch_bundler BUNDLER=[webpack|rspack] [INSTALL_DEPS=true] [NO_UNINSTALL=true]

    Options:
      --install-deps    Automatically install/uninstall bundler dependencies (rake only)
      --no-uninstall    Skip uninstalling old bundler packages (rake only)
      --init-config     Create custom dependencies configuration file
      --help, -h        Show detailed help message

    Environment Variables (for rails command):
      BUNDLER           Target bundler: 'webpack' or 'rspack'
      INSTALL_DEPS      Set to 'true' to automatically install/uninstall dependencies
      NO_UNINSTALL      Set to 'true' to skip uninstalling old bundler packages
      INIT_CONFIG       Set to 'true' to create custom dependencies configuration file

    Examples:
      # Using rake command (note the -- separator)
      rake shakapacker:switch_bundler rspack -- --install-deps
      rake shakapacker:switch_bundler webpack -- --install-deps --no-uninstall
      rake shakapacker:switch_bundler -- --init-config
      rake shakapacker:switch_bundler -- --help

      # Using rails command (with environment variables)
      rails shakapacker:switch_bundler BUNDLER=rspack INSTALL_DEPS=true
      rails shakapacker:switch_bundler BUNDLER=webpack INSTALL_DEPS=true NO_UNINSTALL=true
      rails shakapacker:switch_bundler INIT_CONFIG=true
      rails shakapacker:switch_bundler

    What it does:
      - Updates 'assets_bundler' in config/shakapacker.yml
      - Preserves YAML comments and structure
      - Updates 'javascript_transpiler' to 'swc' when switching to rspack
      - With --install-deps or INSTALL_DEPS=true: installs/uninstalls npm dependencies automatically
      - Without: shows manual installation commands

    Custom Dependencies:
      Create .shakapacker-switch-bundler-dependencies.yml to customize which
      npm packages are installed/uninstalled during bundler switching.

    See docs/rspack_migration_guide.md for more information.
  DESC
  task :switch_bundler do
    switcher = Shakapacker::BundlerSwitcher.new

    # Support both environment variables (for rails command) and ARGV (for rake command)
    bundler = ENV["BUNDLER"] || ARGV[1]
    install_deps = ENV["INSTALL_DEPS"] == "true" || ARGV.include?("--install-deps")
    no_uninstall = ENV["NO_UNINSTALL"] == "true" || ARGV.include?("--no-uninstall")
    init_config = ENV["INIT_CONFIG"] == "true" || ARGV.include?("--init-config")
    show_help = ENV["HELP"] == "true" || ARGV.include?("--help") || ARGV.include?("-h")

    if ARGV.empty? || show_help || (bundler.nil? && !init_config)
      switcher.show_usage
    elsif init_config
      switcher.init_config
    elsif bundler.nil? || bundler.start_with?("-")
      switcher.show_usage
    else
      switcher.switch_to(bundler, install_deps: install_deps, no_uninstall: no_uninstall)
    end

    # Prevent rake from trying to execute arguments as tasks
    ARGV.each { |arg| task arg.to_sym {} }
  end
end
