require "open3"
require "webpacker/compiler_strategy"

class Webpacker::Compiler
  # Additional environment variables that the compiler is being run with
  # Webpacker::Compiler.env['FRONTEND_API_KEY'] = 'your_secret_key'
  cattr_accessor(:env) { {} }

  delegate :config, :logger, to: :webpacker
  delegate :fresh?, :stale?, :compile_success_hook, to: :strategy

  def initialize(webpacker)
    @webpacker = webpacker
    @strategy = Webpacker::CompilerStrategy.from_config
  end

  def compile
    if stale?
      run_webpack.tap do |success|
        compile_success_hook
      end
    else
      logger.debug "Everything's up-to-date. Nothing to do"
      true
    end
  end

  private
    attr_reader :webpacker, :strategy

    def optionalRubyRunner
      bin_webpack_path = config.root_path.join("bin/webpacker")
      first_line = File.readlines(bin_webpack_path).first.chomp
      /ruby/.match?(first_line) ? RbConfig.ruby : ""
    end

    def run_webpack
      logger.info "Compiling..."

      stdout, stderr, status = Open3.capture3(
        webpack_env,
        "#{optionalRubyRunner} ./bin/webpacker",
        chdir: File.expand_path(config.root_path)
      )

      if status.success?
        logger.info "Compiled all packs in #{config.public_output_path}"
        logger.error "#{stderr}" unless stderr.empty?

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

      env.merge("WEBPACKER_ASSET_HOST"        => ENV.fetch("WEBPACKER_ASSET_HOST", ActionController::Base.helpers.compute_asset_host),
                "WEBPACKER_RELATIVE_URL_ROOT" => ENV.fetch("WEBPACKER_RELATIVE_URL_ROOT", ActionController::Base.relative_url_root),
                "WEBPACKER_CONFIG" => webpacker.config_path.to_s)
    end
end
