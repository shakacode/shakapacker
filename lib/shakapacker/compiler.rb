require "open3"
require "shakapacker/compiler_strategy"
require "fileutils"

class Shakapacker::Compiler
  # Additional environment variables that the compiler is being run with
  # Shakapacker::Compiler.env['FRONTEND_API_KEY'] = 'your_secret_key'
  cattr_accessor(:env) { {} }

  delegate :config, :logger, :strategy, to: :instance
  delegate :fresh?, :stale?, :after_compile_hook, to: :strategy

  def initialize(instance)
    @instance = instance
  end

  def compile
    unless stale?
      logger.debug "Everything's up-to-date. Nothing to do"
      return true
    end

    if compiling?
      wait_for_compilation_to_complete
      true
    else
      acquire_ipc_lock do
        run_webpack.tap do |success|
          after_compile_hook
        end
      end
    end
  end

  private
    attr_reader :instance

    def acquire_ipc_lock
      open_lock_file do |lf|
        lf.flock(File::LOCK_EX)
        yield if block_given?
      end
    end

    def locked?
      open_lock_file do |lf|
        lf.flock(File::LOCK_EX | File::LOCK_NB) != 0
      end
    end

    alias compiling? locked?

    def wait_for_compilation_to_complete
      logger.info "Waiting for the compilation to complete..."
      acquire_ipc_lock
    end

    def open_lock_file
      create_lock_file_dir unless File.exist?(lock_file_path)

      File.open(lock_file_path, File::CREAT) do |lf|
        return yield lf
      end
    end

    def create_lock_file_dir
      dirname = File.dirname(lock_file_path)
      FileUtils.mkdir_p(dirname)
    end

    def lock_file_path
      config.root_path.join("tmp/shakapacker.lock")
    end

    def optionalRubyRunner
      first_line = File.readlines(bin_shakapacker_path).first.chomp
      /ruby/.match?(first_line) ? RbConfig.ruby : ""
    end

    def run_webpack
      logger.info "Compiling..."

      stdout, stderr, status = Open3.capture3(
        webpack_env,
        "#{optionalRubyRunner} '#{bin_shakapacker_path}'",
        chdir: File.expand_path(config.root_path)
      )

      if status.success?
        logger.info "Compiled all packs in #{config.public_output_path}"
        logger.warn "#{stderr}" unless stderr.empty?

        if config.webpack_compile_output?
          logger.info stdout
        end
      else
        non_empty_streams = [stdout, stderr].delete_if(&:empty?)
        logger.error "\nCOMPILATION FAILED:\nEXIT STATUS: #{status}\nOUTPUTS:\n#{non_empty_streams.join("\n\n")}"
      end

      status.success?
    end

    def webpack_env
      return env unless defined?(ActionController::Base)

      Shakapacker.set_shakapacker_env_variables_for_backward_compatibility

      env.merge(
        "SHAKAPACKER_ASSET_HOST"        => instance.config.asset_host,
        "SHAKAPACKER_RELATIVE_URL_ROOT" => instance.config.relative_url_root,
        "SHAKAPACKER_CONFIG"            => instance.config_path.to_s
      )
    end

    def bin_shakapacker_path
      if File.exist?(config.root_path.join("bin/shakapacker"))
        config.root_path.join("bin/shakapacker")
      elsif File.exist?(config.root_path.join("bin/webpacker"))
        Shakapacker.puts_deprecation_message(
          Shakapacker.short_deprecation_message(
            "bin/webpacker",
            "bin/shakapacker"
          )
        )
        config.root_path.join("bin/webpacker")
      else
        config.root_path.join("bin/shakapacker")
      end
    end
end
