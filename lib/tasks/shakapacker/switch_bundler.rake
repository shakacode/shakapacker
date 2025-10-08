require "shakapacker/bundler_switcher"

namespace :shakapacker do
  desc "Switch between webpack and rspack bundlers"
  task :switch_bundler do
    switcher = Shakapacker::BundlerSwitcher.new

    if ARGV.empty? || ARGV.include?("--help") || ARGV.include?("-h")
      switcher.show_usage
    elsif ARGV.include?("--init-config")
      switcher.init_config
    else
      bundler = ARGV[1]
      install_deps = ARGV.include?("--install-deps")

      if bundler.nil? || bundler.start_with?("-")
        switcher.show_usage
      else
        switcher.switch_to(bundler, install_deps: install_deps)
      end
    end

    # Prevent rake from trying to execute arguments as tasks
    ARGV.each { |arg| task arg.to_sym {} }
  end
end
