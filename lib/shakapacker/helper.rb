module Shakapacker::Helper
  # Returns the current Shakapacker instance.
  # Could be overridden to use multiple Shakapacker
  # configurations within the same app (e.g. with engines).
  def current_shakapacker_instance
    Shakapacker.instance
  end

  # Computes the relative path for a given Shakapacker asset.
  # Returns the relative path using manifest.json and passes it to path_to_asset helper.
  # This will use path_to_asset internally, so most of their behaviors will be the same.
  #
  # Example:
  #
  #   <%= asset_pack_path 'calendar.css' %> # => "/packs/calendar-1016838bab065ae1e122.css"
  def asset_pack_path(name, **options)
    path_to_asset(current_shakapacker_instance.manifest.lookup!(name), options)
  end

  # Computes the absolute path for a given Shakapacker asset.
  # Returns the absolute path using manifest.json and passes it to url_to_asset helper.
  # This will use url_to_asset internally, so most of their behaviors will be the same.
  #
  # Example:
  #
  #   <%= asset_pack_url 'calendar.css' %> # => "http://example.com/packs/calendar-1016838bab065ae1e122.css"
  def asset_pack_url(name, **options)
    url_to_asset(current_shakapacker_instance.manifest.lookup!(name), options)
  end

  # Computes the relative path for a given Shakapacker image with the same automated processing as image_pack_tag.
  # Returns the relative path using manifest.json and passes it to path_to_asset helper.
  # This will use path_to_asset internally, so most of their behaviors will be the same.
  def image_pack_path(name, **options)
    resolve_path_to_image(name, **options)
  end

  # Computes the absolute path for a given Shakapacker image with the same automated
  # processing as image_pack_tag. Returns the relative path using manifest.json
  # and passes it to path_to_asset helper. This will use path_to_asset internally,
  # so most of their behaviors will be the same.
  def image_pack_url(name, **options)
    resolve_path_to_image(name, **options.merge(protocol: :request))
  end

  # Creates an image tag that references the named pack file.
  #
  # Example:
  #
  #  <%= image_pack_tag 'application.png', size: '16x10', alt: 'Edit Entry' %>
  #  <img alt='Edit Entry' src='/packs/application-k344a6d59eef8632c9d1.png' width='16' height='10' />
  #
  #  <%= image_pack_tag 'picture.png', srcset: { 'picture-2x.png' => '2x' } %>
  #  <img srcset= "/packs/picture-2x-7cca48e6cae66ec07b8e.png 2x" src="/packs/picture-c38deda30895059837cf.png" >
  def image_pack_tag(name, **options)
    if options[:srcset] && !options[:srcset].is_a?(String)
      options[:srcset] = options[:srcset].map do |src_name, size|
        "#{resolve_path_to_image(src_name)} #{size}"
      end.join(", ")
    end

    image_tag(resolve_path_to_image(name), options)
  end

  # Creates a link tag for a favicon that references the named pack file.
  #
  # Example:
  #
  #  <%= favicon_pack_tag 'mb-icon.png', rel: 'apple-touch-icon', type: 'image/png' %>
  #  <link href="/packs/mb-icon-k344a6d59eef8632c9d1.png" rel="apple-touch-icon" type="image/png" />
  def favicon_pack_tag(name, **options)
    favicon_link_tag(resolve_path_to_image(name), options)
  end

  # Creates script tags that reference the js chunks from entrypoints when using split chunks API,
  # as compiled by webpack per the entries list in package/environments/base.js.
  # By default, this list is auto-generated to match everything in
  # app/javascript/entrypoints/*.js and all the dependent chunks. In production mode, the digested reference is automatically looked up.
  # See: https://webpack.js.org/plugins/split-chunks-plugin/
  #
  # Example:
  #
  #   <%= javascript_pack_tag 'calendar', 'map', 'data-turbolinks-track': 'reload' %> # =>
  #   <script src="/packs/vendor-16838bab065ae1e314.chunk.js" data-turbolinks-track="reload" defer="true"></script>
  #   <script src="/packs/calendar~runtime-16838bab065ae1e314.chunk.js" data-turbolinks-track="reload" defer="true"></script>
  #   <script src="/packs/calendar-1016838bab065ae1e314.chunk.js" data-turbolinks-track="reload" defer="true"></script>
  #   <script src="/packs/map~runtime-16838bab065ae1e314.chunk.js" data-turbolinks-track="reload" defer="true"></script>
  #   <script src="/packs/map-16838bab065ae1e314.chunk.js" data-turbolinks-track="reload" defer="true"></script>
  #
  # DO:
  #
  #   <%= javascript_pack_tag 'calendar', 'map' %>
  #
  # DON'T:
  #
  #   <%= javascript_pack_tag 'calendar' %>
  #   <%= javascript_pack_tag 'map' %>
  #
  # Early Hints:
  #   By default, HTTP 103 Early Hints are sent automatically when this helper is called,
  #   allowing browsers to preload JavaScript assets in parallel with Rails rendering.
  #
  #   <%= javascript_pack_tag 'application' %>
  #   # Automatically sends early hints for 'application' pack
  #
  #   # Customize handling per pack:
  #   <%= javascript_pack_tag 'application', 'vendor',
  #         early_hints: { 'application' => 'preload', 'vendor' => 'prefetch' } %>
  #
  #   # Disable early hints:
  #   <%= javascript_pack_tag 'application', early_hints: false %>
  def javascript_pack_tag(*names, defer: true, async: false, early_hints: "preload", **options)
    if @javascript_pack_tag_loaded
      raise "To prevent duplicated chunks on the page, you should call javascript_pack_tag only once on the page. " \
      "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helpers-javascript_pack_tag-and-stylesheet_pack_tag for the usage guide"
    end

    # Collect all packs (queue + direct args)
    append_javascript_pack_tag(*names, defer: defer, async: async)
    all_packs = javascript_pack_tag_queue.values.flatten.uniq

    # Send early hints automatically if enabled
    if early_hints_enabled? && early_hints && early_hints != "none" && early_hints != false
      hints_config = normalize_pack_hints(all_packs, early_hints)
      send_javascript_early_hints_internal(hints_config)
      # Flush accumulated hints (sends the single 103 response)
      flush_early_hints
    elsif early_hints_debug_enabled?
      @early_hints_debug_buffer ||= []
      @early_hints_debug_buffer << "<!-- Shakapacker Early Hints (JS): SKIPPED (early_hints: #{early_hints.inspect}) -->"
    end

    sync = sources_from_manifest_entrypoints(javascript_pack_tag_queue[:sync], type: :javascript)
    async = sources_from_manifest_entrypoints(javascript_pack_tag_queue[:async], type: :javascript) - sync
    deferred = sources_from_manifest_entrypoints(javascript_pack_tag_queue[:deferred], type: :javascript) - sync - async

    @javascript_pack_tag_loaded = true

    capture do
      # Output debug buffer first
      if early_hints_debug_enabled? && @early_hints_debug_buffer && @early_hints_debug_buffer.any?
        concat @early_hints_debug_buffer.join("\n").html_safe
        concat "\n"
      end

      render_tags(async, :javascript, **options.dup.tap { |o| o[:async] = true })
      concat "\n" if async.any? && deferred.any?
      render_tags(deferred, :javascript, **options.dup.tap { |o| o[:defer] = true })
      concat "\n" if sync.any? && deferred.any?
      render_tags(sync, :javascript, options)
    end
  end

  # Creates a link tag, for preloading, that references a given Shakapacker asset.
  # In production mode, the digested reference is automatically looked up.
  # See: https://developer.mozilla.org/en-US/docs/Web/HTML/Preloading_content
  #
  # Example:
  #
  #   <%= preload_pack_asset 'fonts/fa-regular-400.woff2' %> # =>
  #   <link rel="preload" href="/packs/fonts/fa-regular-400-944fb546bd7018b07190a32244f67dc9.woff2" as="font" type="font/woff2" crossorigin="anonymous">
  def preload_pack_asset(name, **options)
    if self.class.method_defined?(:preload_link_tag)
      preload_link_tag(current_shakapacker_instance.manifest.lookup!(name), options)
    else
      raise "You need Rails >= 5.2 to use this tag."
    end
  end

  # Sends HTTP 103 Early Hints for specified packs with fine-grained control over
  # JavaScript and CSS handling. This is the "raw" method for maximum flexibility.
  #
  # Use this in controller actions BEFORE expensive work (database queries, API calls)
  # to maximize parallelism - the browser downloads assets while Rails processes the request.
  #
  # For simpler cases, use javascript_pack_tag and stylesheet_pack_tag which automatically
  # send hints when called (combining queued + direct pack names).
  #
  # HTTP 103 Early Hints allows the server to send preliminary responses with Link headers
  # before the final HTTP 200 response, enabling browsers to start downloading critical
  # assets during the server's "think time".
  #
  # Timeline:
  #   1. Browser requests page
  #   2. Controller calls send_pack_early_hints (this method)
  #   3. Server sends HTTP 103 with Link: headers
  #   4. Browser starts downloading assets IN PARALLEL with step 5
  #   5. Rails continues expensive work (queries, rendering)
  #   6. Server sends HTTP 200 with full HTML
  #   7. Assets already downloaded = faster page load
  #
  # Requires Rails 5.2+, HTTP/2, and server support (Puma 5+, nginx 1.13+).
  # Gracefully degrades if not supported.
  #
  # References:
  # - Rails API: https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-send_early_hints
  # - HTTP 103 Spec: https://datatracker.ietf.org/doc/html/rfc8297
  #
  # Examples:
  #
  #   # Controller pattern: send hints BEFORE expensive work
  #   def show
  #     send_pack_early_hints({
  #       "application" => { js: "preload", css: "preload" },
  #       "vendor" => { js: "prefetch", css: "none" }
  #     })
  #
  #     # Browser now downloading assets while we do expensive work
  #     @posts = Post.includes(:comments, :author).where(complex_conditions)
  #     # ... more expensive work ...
  #   end
  #
  #   # Supported handling values:
  #   # - "preload": High-priority, browser downloads immediately
  #   # - "prefetch": Low-priority, browser may download when idle
  #   # - "none" or false: Skip this asset type for this pack
  def send_pack_early_hints(config)
    return nil unless early_hints_supported? && early_hints_enabled?

    # Accumulate both JS and CSS hints, then send ONCE
    config.each do |pack_name, handlers|
      # Accumulate JavaScript hints
      js_handling = handlers[:js] || handlers["js"]
      if js_handling && js_handling != "none" && js_handling != false
        send_early_hints_internal({ pack_name.to_s => js_handling.to_s }, type: :javascript)
      end

      # Accumulate CSS hints
      css_handling = handlers[:css] || handlers["css"]
      if css_handling && css_handling != "none" && css_handling != false
        send_early_hints_internal({ pack_name.to_s => css_handling.to_s }, type: :stylesheet)
      end
    end

    # Flush the accumulated hints as a SINGLE 103 response
    # (Browsers only process the first 103)
    flush_early_hints

    nil
  end

  # Creates link tags that reference the css chunks from entrypoints when using split chunks API,
  # as compiled by webpack per the entries list in package/environments/base.js.
  # By default, this list is auto-generated to match everything in
  # app/javascript/entrypoints/*.js and all the dependent chunks. In production mode, the digested reference is automatically looked up.
  # See: https://webpack.js.org/plugins/split-chunks-plugin/
  #
  # Examples:
  #
  #   <%= stylesheet_pack_tag 'calendar', 'map' %> # =>
  #   <link rel="stylesheet" media="screen" href="/packs/3-8c7ce31a.chunk.css" />
  #   <link rel="stylesheet" media="screen" href="/packs/calendar-8c7ce31a.chunk.css" />
  #   <link rel="stylesheet" media="screen" href="/packs/map-8c7ce31a.chunk.css" />
  #
  #   When using the webpack-dev-server, CSS is inlined so HMR can be turned on for CSS,
  #   including CSS modules
  #   <%= stylesheet_pack_tag 'calendar', 'map' %> # => nil
  #
  # DO:
  #
  #   <%= stylesheet_pack_tag 'calendar', 'map' %>
  #
  # DON'T:
  #
  #   <%= stylesheet_pack_tag 'calendar' %>
  #   <%= stylesheet_pack_tag 'map' %>
  #
  # Early Hints:
  #   By default, HTTP 103 Early Hints are sent automatically when this helper is called,
  #   allowing browsers to preload CSS assets in parallel with Rails rendering.
  #
  #   <%= stylesheet_pack_tag 'application' %>
  #   # Automatically sends early hints for 'application' pack
  #
  #   # Customize handling per pack:
  #   <%= stylesheet_pack_tag 'application', 'vendor',
  #         early_hints: { 'application' => 'preload', 'vendor' => 'prefetch' } %>
  #
  #   # Disable early hints:
  #   <%= stylesheet_pack_tag 'application', early_hints: false %>
  def stylesheet_pack_tag(*names, early_hints: "preload", **options)
    return "" if Shakapacker.inlining_css?

    # Collect all packs (queue + direct args)
    all_packs = ((@stylesheet_pack_tag_queue || []) + names).uniq

    # Send early hints automatically if enabled
    if early_hints_enabled? && early_hints && early_hints != "none" && early_hints != false
      hints_config = normalize_pack_hints(all_packs, early_hints)
      send_stylesheet_early_hints_internal(hints_config)
      # Flush accumulated hints (sends the single 103 response)
      flush_early_hints
    elsif early_hints_debug_enabled?
      @early_hints_debug_buffer ||= []
      @early_hints_debug_buffer << "<!-- Shakapacker Early Hints (CSS): SKIPPED (early_hints: #{early_hints.inspect}) -->"
    end

    requested_packs = sources_from_manifest_entrypoints(names, type: :stylesheet)
    appended_packs = available_sources_from_manifest_entrypoints(@stylesheet_pack_tag_queue || [], type: :stylesheet)

    @stylesheet_pack_tag_loaded = true

    capture do
      # Output debug buffer first
      if early_hints_debug_enabled? && @early_hints_debug_buffer && @early_hints_debug_buffer.any?
        concat @early_hints_debug_buffer.join("\n").html_safe
        concat "\n"
      end

      render_tags(requested_packs | appended_packs, :stylesheet, options)
    end
  end

  def append_stylesheet_pack_tag(*names)
    if @stylesheet_pack_tag_loaded
      raise "You can only call append_stylesheet_pack_tag before stylesheet_pack_tag helper. " \
      "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"
    end

    @stylesheet_pack_tag_queue ||= []
    @stylesheet_pack_tag_queue.concat names

    # prevent rendering Array#to_s representation when used with <%= … %> syntax
    nil
  end

  def append_javascript_pack_tag(*names, defer: true, async: false)
    update_javascript_pack_tag_queue(defer: defer, async: async) do |hash_key|
      javascript_pack_tag_queue[hash_key] |= names
    end
  end

  def prepend_javascript_pack_tag(*names, defer: true, async: false)
    update_javascript_pack_tag_queue(defer: defer, async: async) do |hash_key|
      javascript_pack_tag_queue[hash_key].unshift(*names)
    end
  end

  private

    def update_javascript_pack_tag_queue(defer:, async:)
      if @javascript_pack_tag_loaded
        raise "You can only call #{caller_locations(1..1).first.base_label} before javascript_pack_tag helper. " \
        "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helper-append_javascript_pack_tag-prepend_javascript_pack_tag-and-append_stylesheet_pack_tag for the usage guide"
      end

      # When both async and defer are specified, async takes precedence per HTML5 spec
      hash_key = if async
        :async
      elsif defer
        :deferred
      else
        :sync
      end
      yield(hash_key)

      # prevent rendering Array#to_s representation when used with <%= … %> syntax
      nil
    end

    def javascript_pack_tag_queue
      @javascript_pack_tag_queue ||= {
        async: [],
        deferred: [],
        sync: []
      }
    end

    def sources_from_manifest_entrypoints(names, type:)
      names.map { |name| current_shakapacker_instance.manifest.lookup_pack_with_chunks!(name.to_s, type: type) }.flatten.uniq
    end

    def available_sources_from_manifest_entrypoints(names, type:)
      names.map { |name| current_shakapacker_instance.manifest.lookup_pack_with_chunks(name.to_s, type: type) }.flatten.compact.uniq
    end

    def resolve_path_to_image(name, **options)
      path = name.starts_with?("static/") ? name : "static/#{name}"
      path_to_asset(current_shakapacker_instance.manifest.lookup!(path), options)
    rescue
      path_to_asset(current_shakapacker_instance.manifest.lookup!(name), options)
    end

    def lookup_integrity(source)
      (source.respond_to?(:dig) && source.dig("integrity")) || nil
    end

    def lookup_source(source)
      (source.respond_to?(:dig) && source.dig("src")) || source
    end

    # Handles rendering javascript and stylesheet tags with integrity, if that's enabled.
    def render_tags(sources, type, options)
      return unless sources.present? || type.present?

      sources.each.with_index do |source, index|
        tag_source = lookup_source(source)

        if current_shakapacker_instance.config.integrity[:enabled]
          integrity = lookup_integrity(source)

          if integrity.present?
            options[:integrity] = integrity
            options[:crossorigin] = current_shakapacker_instance.config.integrity[:cross_origin]
          end
        end

        if type == :javascript
          # Disable Rails' built-in early hints (nopush: true) since we handle early hints ourselves
          concat javascript_include_tag(tag_source, **options.merge(nopush: true))
        else
          # Disable Rails' built-in early hints (nopush: true) since we handle early hints ourselves
          concat stylesheet_link_tag(tag_source, **options.merge(nopush: true))
        end

        concat "\n" unless index == sources.size - 1
      end
    end

    # Check if early hints are supported by Rails and the request object
    def early_hints_supported?
      request.respond_to?(:send_early_hints)
    end

    # Check if early hints are enabled in configuration
    def early_hints_enabled?
      config = current_shakapacker_instance.config.early_hints
      return false unless config
      config[:enabled] == true
    end

    # Check if early hints debug mode is enabled
    def early_hints_debug_enabled?
      config = current_shakapacker_instance.config.early_hints
      return false unless config
      config[:debug] == true
    end

    # Generate reason why early hints were skipped
    def early_hints_skip_reason
      unless early_hints_supported?
        return "Rails request.send_early_hints not available (requires Rails 5.2+)"
      end
      unless early_hints_enabled?
        return "early_hints.enabled is false in config/shakapacker.yml"
      end
      "Unknown reason"
    end

    # Build a Link header value for early hints
    # Takes the already-resolved source_path to avoid duplicate lookup_source calls
    def build_link_header(source_path, source, as:, rel: "preload")
      parts = ["<#{source_path}>", "rel=#{rel}", "as=#{as}"]

      # Add crossorigin and integrity if enabled (consistent with render_tags)
      if current_shakapacker_instance.config.integrity[:enabled]
        integrity = lookup_integrity(source)
        if integrity.present?
          parts << "integrity=\"#{integrity}\""
          # Use configured cross_origin value, consistent with render_tags
          cross_origin = current_shakapacker_instance.config.integrity[:cross_origin]
          parts << "crossorigin=\"#{cross_origin}\""
        end
      elsif ["script", "style", "font"].include?(as)
        # When integrity not enabled, scripts, styles, and fonts still need crossorigin for CORS
        parts << "crossorigin=\"anonymous\""
      end

      parts.join("; ")
    end

    # Normalize pack hints configuration to a hash mapping pack names to handling
    # Input can be:
    #   - String: "preload" applies to all packs
    #   - Hash: { "application" => "preload", "vendor" => "prefetch" }
    # Returns: { "pack1" => "preload", "pack2" => "prefetch" }
    def normalize_pack_hints(pack_names, hints_config)
      if hints_config.is_a?(Hash)
        # Already a hash, ensure all pack names have entries (default to "preload")
        result = {}
        pack_names.each do |pack|
          result[pack.to_s] = hints_config[pack]&.to_s || hints_config[pack.to_s] || "preload"
        end
        result
      else
        # String or symbol, apply to all packs
        handling = hints_config.to_s
        pack_names.each_with_object({}) { |pack, h| h[pack.to_s] = handling }
      end
    end

    # Internal method to accumulate and send early hints
    # Sends only ONE 103 response (browsers ignore subsequent ones)
    # config: { "application" => "preload", "vendor" => "prefetch" }
    # type: :javascript or :stylesheet
    def send_early_hints_internal(config, type:)
      return unless early_hints_supported?

      # Track hints per-type to avoid duplicates within a type
      # But allow same pack for different types (JS + CSS)
      @early_hints_sent_packs ||= { javascript: {}, stylesheet: {} }
      @early_hints_link_buffer ||= []
      @early_hints_debug_buffer ||= []

      # If we've already sent the 103 response, just track for debug
      if @early_hints_103_sent
        if early_hints_debug_enabled?
          @early_hints_debug_buffer << "<!-- Shakapacker Early Hints (#{type.upcase}): Not sent (103 already sent) -->"
          @early_hints_debug_buffer << "<!--   Packs: #{config.keys.join(', ')} -->"
        end
        return
      end

      # Filter to only new packs for THIS type
      new_hints = config.reject { |pack, _handling| @early_hints_sent_packs[type].key?(pack) }

      if early_hints_debug_enabled? && new_hints.empty?
        @early_hints_debug_buffer << "<!-- Shakapacker Early Hints (#{type.upcase}): All packs already queued -->"
      end

      # Accumulate Link headers for this type
      asset_type = type == :javascript ? "script" : "style"
      new_hints.each do |pack_name, handling|
        begin
          sources = available_sources_from_manifest_entrypoints([pack_name], type: type)
          sources.each do |source|
            source_path = lookup_source(source)
            @early_hints_link_buffer << build_link_header(source_path, source, as: asset_type, rel: handling)
          end
          # Mark pack as queued for THIS type
          @early_hints_sent_packs[type][pack_name] = handling
        rescue Shakapacker::Manifest::MissingEntryError, NoMethodError => e
          Rails.logger.debug { "Early hints: skipping pack '#{pack_name}' - #{e.class}: #{e.message}" }
        end
      end

      # Note: We DON'T flush here - caller must call flush_early_hints explicitly
      # This allows accumulating multiple calls (JS + CSS) before sending ONE 103
    end

    # Send accumulated early hints as a SINGLE 103 response
    # Browsers only process the first 103, so we send everything at once
    def flush_early_hints
      # Guard against multiple flushes - only send once per request
      return if defined?(@early_hints_103_sent) && @early_hints_103_sent
      return if @early_hints_link_buffer.nil? || @early_hints_link_buffer.empty?

      @early_hints_103_sent = true  # Set flag BEFORE sending to prevent race conditions
      request.send_early_hints({ "Link" => @early_hints_link_buffer.join(", ") })

      if early_hints_debug_enabled?
        all_packs = (@early_hints_sent_packs[:javascript].keys + @early_hints_sent_packs[:stylesheet].keys).uniq
        @early_hints_debug_buffer << "<!-- Shakapacker Early Hints: HTTP/1.1 103 SENT -->"
        @early_hints_debug_buffer << "<!--   Total Links: #{@early_hints_link_buffer.size} -->"
        @early_hints_debug_buffer << "<!--   Packs: #{all_packs.join(', ')} -->"
        @early_hints_debug_buffer << "<!--   JS Packs: #{@early_hints_sent_packs[:javascript].keys.join(', ')} -->"
        @early_hints_debug_buffer << "<!--   CSS Packs: #{@early_hints_sent_packs[:stylesheet].keys.join(', ')} -->"
        @early_hints_debug_buffer << "<!--   Headers: -->"
        @early_hints_link_buffer.each do |link|
          @early_hints_debug_buffer << "<!--     #{link} -->"
        end
        @early_hints_debug_buffer << "<!--   Note: Browsers only process the FIRST 103 response -->"
        @early_hints_debug_buffer << "<!--   Note: Puma only supports HTTP/1.1 Early Hints (not HTTP/2) -->"
      end
    end

    # Wrapper for JavaScript early hints
    def send_javascript_early_hints_internal(config)
      send_early_hints_internal(config, type: :javascript)
    end

    # Wrapper for stylesheet early hints
    def send_stylesheet_early_hints_internal(config)
      send_early_hints_internal(config, type: :stylesheet)
    end
end
