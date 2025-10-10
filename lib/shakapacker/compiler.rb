require "open3"
require "fileutils"
require "shellwords"

require_relative "compiler_strategy"

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
        run_precompile_hook if config.precompile_hook
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

    def optional_ruby_runner
      first_line = File.readlines(bin_shakapacker_path).first.chomp
      /ruby/.match?(first_line) ? RbConfig.ruby : ""
    end

    def run_precompile_hook
      hook_command = config.precompile_hook
      validate_precompile_hook(hook_command)

      logger.info "Running precompile hook: #{hook_command}"

      stdout, stderr, status = Open3.capture3(
        webpack_env,
        hook_command,
        chdir: File.expand_path(config.root_path)
      )

      if status.success?
        logger.info "Precompile hook completed successfully"
        logger.info stdout unless stdout.empty?
        logger.warn stderr unless stderr.empty?
      else
        non_empty_streams = [stdout, stderr].delete_if(&:empty?)
        logger.error "\nPRECOMPILE HOOK FAILED:\nEXIT STATUS: #{status.exitstatus}\nCOMMAND: #{hook_command}\nOUTPUTS:\n#{non_empty_streams.join("\n\n")}"
        logger.error "\nTo fix this:"
        logger.error "  1. Check that the hook script exists and is executable"
        logger.error "  2. Test the hook command manually: #{hook_command}"
        logger.error "  3. Review the error output above for details"
        logger.error "  4. You can disable the hook temporarily by commenting out 'precompile_hook' in shakapacker.yml"
        raise "Precompile hook '#{hook_command}' failed with exit status #{status.exitstatus}"
      end
    end

    def validate_precompile_hook(hook_command)
      # Extract the executable path (first word/token before any arguments)
      # Uses Shellwords to properly handle paths with spaces and quoted arguments
      # Examples: "bin/script", "bin/script --arg", "'bin/my script' --arg"
      executable = Shellwords.shellwords(hook_command).first
      executable_path = config.root_path.join(executable)

      # Security: Resolve symlinks and verify the hook points to a file within the project
      # This prevents symlink bypass attacks and path traversal attacks
      begin
        resolved_path = executable_path.realpath
        resolved_root = config.root_path.realpath
      rescue Errno::ENOENT
        # If file doesn't exist, use cleanpath for basic validation
        resolved_path = executable_path.cleanpath
        resolved_root = config.root_path.cleanpath
      end

      # Verify path is within project root with proper separator check
      # Using File::SEPARATOR prevents partial path matches (e.g., /project vs /project-evil)
      unless resolved_path.to_s.start_with?(resolved_root.to_s + File::SEPARATOR)
        raise "Security Error: precompile_hook must reference a script within the project root. " \
              "Got: #{hook_command} (resolved to: #{resolved_path})"
      end

      # Warn if the executable doesn't exist within the project
      unless File.exist?(executable_path)
        logger.warn "⚠️  Warning: precompile_hook executable not found: #{executable_path}"
        logger.warn "   The hook command is configured but the script does not exist within the project root."
        logger.warn "   Please ensure the script exists or remove 'precompile_hook' from your shakapacker.yml configuration."
      end
    end

    def run_webpack
      logger.info "Compiling..."

      stdout, stderr, status = Open3.capture3(
        webpack_env,
        "#{optional_ruby_runner} '#{bin_shakapacker_path}'",
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

      env.merge(
        "SHAKAPACKER_ASSET_HOST" => instance.config.asset_host,
        "SHAKAPACKER_CONFIG"     => instance.config.config_path.to_s
      )
    end

    def bin_shakapacker_path
      config.root_path.join("bin/shakapacker")
    end
end
