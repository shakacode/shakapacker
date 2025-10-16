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
  def javascript_pack_tag(*names, defer: true, async: false, early_hints: false, **options)
    if @javascript_pack_tag_loaded
      raise "To prevent duplicated chunks on the page, you should call javascript_pack_tag only once on the page. " \
      "Please refer to https://github.com/shakacode/shakapacker/blob/main/README.md#view-helpers-javascript_pack_tag-and-stylesheet_pack_tag for the usage guide"
    end

    # Send early hints if requested
    if early_hints
      early_hints_options = early_hints.is_a?(Hash) ? early_hints : {}
      send_pack_early_hints(*names, **early_hints_options)
    end

    append_javascript_pack_tag(*names, defer: defer, async: async)
    sync = sources_from_manifest_entrypoints(javascript_pack_tag_queue[:sync], type: :javascript)
    async = sources_from_manifest_entrypoints(javascript_pack_tag_queue[:async], type: :javascript) - sync
    deferred = sources_from_manifest_entrypoints(javascript_pack_tag_queue[:deferred], type: :javascript) - sync - async

    @javascript_pack_tag_loaded = true

    capture do
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

  # Sends HTTP 103 Early Hints for the specified packs to enable browsers to preload
  # critical assets while Rails is still rendering the response.
  # This can significantly improve perceived page load performance.
  #
  # HTTP 103 Early Hints is a status code that allows the server to send preliminary
  # responses with Link headers before the final HTTP 200 response. This enables
  # browsers to start downloading critical assets during the server's "think time"
  # while Rails is still rendering views and processing the request.
  #
  # Timeline:
  #   1. Browser requests page
  #   2. Server sends HTTP 103 with Link: headers (this helper)
  #   3. Browser starts downloading assets in parallel
  #   4. Server finishes rendering and sends HTTP 200 with full HTML
  #   5. Assets arrive faster because browser started downloading earlier
  #
  # Requires Rails 5.2+ (for request.send_early_hints) and server support (e.g., Puma 5+, nginx 1.13+).
  # Gracefully degrades if not supported - no errors will occur.
  #
  # Important: Call this helper as early as possible in your layout for optimal performance.
  # The earlier it's called, the sooner the browser can start downloading assets while
  # Rails is still rendering the rest of the page.
  #
  # References:
  # - Rails API: https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-send_early_hints
  # - Eileen Codes: https://eileencodes.com/posts/http2-early-hints/
  # - HTTP 103 Spec: https://datatracker.ietf.org/doc/html/rfc8297
  #
  # Example:
  #
  #   # Option 1: No arguments - reads from pack queues (recommended)
  #   # Queues are populated by append_javascript_pack_tag / append_stylesheet_pack_tag in views
  #   <% send_pack_early_hints %>
  #   <!DOCTYPE html>
  #   <html>
  #     <head>
  #       <%= stylesheet_pack_tag 'application' %>
  #     </head>
  #     <body>
  #       <%= yield %>  <%# Views already rendered, queues populated! %>
  #       <%= javascript_pack_tag 'application' %>
  #     </body>
  #   </html>
  #
  #   # How it works:
  #   # 1. Views/partials render and call append_javascript_pack_tag('foo')
  #   # 2. Layout renders (views already done!)
  #   # 3. send_pack_early_hints() reads pack names from queues
  #   # 4. Early hints sent with all packs that will be used
  #
  #   # Option 2: Explicit pack names (when you know them upfront)
  #   <% send_pack_early_hints 'application', 'admin' %>
  #
  #   # Option 3: With options (rarely needed)
  #   <% send_pack_early_hints 'application',
  #        include_css: true,   # default: from config
  #        include_js: true     # default: from config
  #   %>
  def send_pack_early_hints(*names, **options)
    return unless early_hints_supported? && early_hints_enabled?

    # Mark that we've manually sent early hints to prevent automatic sending
    # Use request.env for shared storage between view context and controller
    request.env["shakapacker.skip_early_hints"] = true if request.respond_to?(:env)

    # If no pack names provided, collect from queues populated by append/prepend helpers
    # This allows zero-config usage: views call append_*, then layout calls send_pack_early_hints
    if names.empty?
      names = collect_pack_names_from_queues
      # If queues are empty, nothing to send
      return nil if names.empty?
    end

    headers = build_early_hints_links(names, **options)
    request.send_early_hints(headers) unless headers.empty?

    # Return nil to avoid rendering output with <%= %>
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
  def stylesheet_pack_tag(*names, **options)
    return "" if Shakapacker.inlining_css?

    requested_packs = sources_from_manifest_entrypoints(names, type: :stylesheet)
    appended_packs = available_sources_from_manifest_entrypoints(@stylesheet_pack_tag_queue || [], type: :stylesheet)

    @stylesheet_pack_tag_loaded = true

    capture do
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
          concat javascript_include_tag(tag_source, **options)
        else
          concat stylesheet_link_tag(tag_source, **options)
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

    # Collect pack names from queues populated by append/prepend helpers
    # This allows send_pack_early_hints to work without arguments
    def collect_pack_names_from_queues
      names = []

      # Collect from javascript pack queue (all async/deferred/sync)
      if defined?(@javascript_pack_tag_queue) && @javascript_pack_tag_queue
        names.concat(@javascript_pack_tag_queue.values.flatten)
      end

      # Collect from stylesheet pack queue
      if defined?(@stylesheet_pack_tag_queue) && @stylesheet_pack_tag_queue
        names.concat(@stylesheet_pack_tag_queue)
      end

      names.uniq.map(&:to_s)
    end

    # Build early hints Link headers for the specified packs
    # Returns a headers hash in the format expected by Rails: {"Link" => [array of link strings]}
    def build_early_hints_links(names, **options)
      link_headers = []

      names.each do |name|
        # Collect JavaScript chunks
        include_js, js_rel = should_include_hint?(:js, **options)
        if include_js
          begin
            sources = available_sources_from_manifest_entrypoints([name], type: :javascript)
            sources.each do |source|
              source_path = lookup_source(source)
              link_headers << build_link_header(source_path, source, as: "script", rel: js_rel)
            end
          rescue Shakapacker::Manifest::MissingEntryError, NoMethodError => e
            # Gracefully handle missing entries or nil manifest responses
            Rails.logger.debug { "Early hints: skipping pack '#{name}' JS - #{e.class}: #{e.message}" }
          end
        end

        # Collect CSS chunks
        include_css, css_rel = should_include_hint?(:css, **options)
        if include_css
          begin
            sources = available_sources_from_manifest_entrypoints([name], type: :stylesheet)
            sources.each do |source|
              source_path = lookup_source(source)
              link_headers << build_link_header(source_path, source, as: "style", rel: css_rel)
            end
          rescue Shakapacker::Manifest::MissingEntryError, NoMethodError => e
            # Gracefully handle missing entries or nil manifest responses
            Rails.logger.debug { "Early hints: skipping pack '#{name}' CSS - #{e.class}: #{e.message}" }
          end
        end
      end

      # Add custom links from request.env (images, videos, etc)
      if request.respond_to?(:env) && request.env["shakapacker.custom_links"]
        request.env["shakapacker.custom_links"].each do |link|
          header = build_custom_link_header(link)
          link_headers << header if header
        end
      end

      link_headers.any? ? { "Link" => link_headers.join(", ") } : {}
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

    # Build Link header for a custom resource (image, video, etc)
    # Accepts hash with :href, :as, :type, :rel (optional), :crossorigin (optional)
    def build_custom_link_header(link)
      href = link[:href] || link["href"]
      as = link[:as] || link["as"]
      type = link[:type] || link["type"]
      rel = link[:rel] || link["rel"] || "preload"
      crossorigin = link[:crossorigin] || link["crossorigin"]

      return nil unless href && as

      parts = ["<#{href}>", "rel=#{rel}", "as=#{as}"]
      parts << "type=\"#{type}\"" if type
      parts << "crossorigin=\"#{crossorigin}\"" if crossorigin

      parts.join("; ")
    end

    # Configure early hints for the current request
    # Can be called from controller actions or before_action
    # Supports 'all' shortcut, specific css/js configuration, and custom links
    #
    # Examples:
    #   configure_early_hints css: 'prefetch', js: 'preload'
    #   configure_early_hints all: 'none'
    #   configure_early_hints all: 'prefetch', js: 'preload'
    #   configure_early_hints links: [
    #     { href: '/images/hero.jpg', as: 'image', type: 'image/jpeg' },
    #     { href: '/videos/intro.mp4', as: 'video', type: 'video/mp4' }
    #   ]
    def configure_early_hints(all: nil, css: nil, js: nil, links: nil)
      return unless request.respond_to?(:env)

      # Apply 'all' shortcut first
      if all
        request.env["shakapacker.css_hint"] = normalize_hint_value(all)
        request.env["shakapacker.js_hint"] = normalize_hint_value(all)
      end

      # Specific values override 'all'
      request.env["shakapacker.css_hint"] = normalize_hint_value(css) if css
      request.env["shakapacker.js_hint"] = normalize_hint_value(js) if js

      # Store custom links
      if links
        request.env["shakapacker.custom_links"] ||= []
        request.env["shakapacker.custom_links"].concat(Array(links))
      end
    end

    # Resolve hint type for a given asset type (css or js)
    # Checks request.env first (per-request config), then falls back to global config
    # Returns 'preload', 'prefetch', or 'none'
    def resolve_hint_type(asset_type, **options)
      # Check explicit option passed to method (highest priority)
      # Support both new format (css:/js:) and old format (include_css:/include_js:)
      if options.key?(asset_type)
        return normalize_hint_value(options[asset_type])
      elsif options.key?("include_#{asset_type}".to_sym)
        return normalize_hint_value(options["include_#{asset_type}".to_sym])
      end

      # Check request.env for per-request configuration
      if request.respond_to?(:env)
        env_key = "shakapacker.#{asset_type}_hint"
        return request.env[env_key] if request.env[env_key]
      end

      # Fall back to global config
      config = current_shakapacker_instance.config.early_hints || {}

      # Try new format first (css/js), then old format (include_css/include_js) for backward compat
      # Use has_key? to distinguish between false and nil
      value = if config.key?(asset_type)
        config[asset_type]
              elsif config.key?(asset_type.to_s)
                config[asset_type.to_s]
              elsif config.key?("include_#{asset_type}".to_sym)
                config["include_#{asset_type}".to_sym]
              elsif config.key?("include_#{asset_type}")
                config["include_#{asset_type}"]
      end

      normalize_hint_value(value)
    end

    # Normalize hint value to standard string
    # Handles backward compatibility: true -> 'preload', false -> 'none'
    # Returns 'preload', 'prefetch', or 'none'
    def normalize_hint_value(value)
      case value
      when true, "preload", :preload
        "preload"
      when false, "none", :none
        "none"
      when "prefetch", :prefetch
        "prefetch"
      else
        "preload" # default
      end
    end

    # Check if hints should be included for a given asset type
    # Returns: [should_include?, rel_value]
    def should_include_hint?(asset_type, **options)
      hint_type = resolve_hint_type(asset_type, **options)
      case hint_type
      when "none"
        [false, nil]
      when "prefetch"
        [true, "prefetch"]
      else # 'preload'
        [true, "preload"]
      end
    end
end
