# HTTP 103 Early Hints Guide

This guide shows you how to use HTTP 103 Early Hints with Shakapacker to optimize page load performance.

## What are Early Hints?

HTTP 103 Early Hints is emitted **after** Rails has finished rendering but **before** the final response is sent, allowing browsers to begin fetching resources (JS, CSS) prior to receiving the full HTML response. This may significantly improve page load performance or cause an equally significant regression, depending on the page's content.

⚠️ **Critical**: Preloading JavaScript may hurt your LCP (Largest Contentful Paint) metric if you have large images, videos, or other content that should load first. **Careful experimentation and performance measurement is required.**

### Priority Levels: Preload vs Prefetch vs None

Early hints let you control browser download priority for assets:

- **`preload`** - **Prioritize**: High priority, browser downloads immediately before HTML parsing. Use for critical assets needed for initial render.
- **`prefetch`** - **De-prioritize**: Low priority, browser downloads when idle (doesn't compete for bandwidth). Use for non-critical assets or future navigation.
- **`none`** - **Default behavior**: No hint sent. Browser discovers asset when parsing HTML (normal page load behavior).

### Performance Considerations

⚠️ **Important**: Different pages have different performance characteristics:

- **LCP Impact**: Preloading JS/CSS competes for bandwidth with images/videos, potentially delaying LCP
- **Hero Images**: Pages with large hero images usually perform **worse** with JS/CSS preload
- **Interactive Apps**: Dashboards and SPAs may benefit from aggressive JS preload
- **Content Sites**: Blogs and marketing sites often need conservative hints (prefetch or none)
- **Recommendation**: Configure hints **per-page** based on content, measure with real user data

## Quick Start

### 1. Global Configuration

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true # Master switch
    css: "preload" # 'preload' | 'prefetch' | 'none'
    js: "preload" # 'preload' | 'prefetch' | 'none'
```

**Defaults**: When `enabled: true`, both `css` and `js` default to `'preload'` if not specified.

**Testing**: See the [Feature Testing Guide](feature_testing.md#http-103-early-hints) for detailed instructions on verifying early hints are working using browser DevTools or curl.

### 2. Controller Implementation (Required)

**CRITICAL**: Call `send_pack_early_hints` BEFORE expensive work in your controller to allow asset downloads during rendering:

```ruby
class PostsController < ApplicationController
  def index
    # Send early hints FIRST - browser starts downloading while we work
    view_context.send_pack_early_hints('application', 'posts')

    # Now do expensive work - assets download in parallel
    @posts = Post.includes(:author, :comments).paginate(page: params[:page])
  end
end
```

**Why this works:**

1. Browser requests page
2. `send_pack_early_hints` sends HTTP 103 immediately
3. Browser starts downloading `application.js`, `application.css`, `posts.js`, `posts.css`
4. While browser downloads, Rails runs expensive query
5. By the time HTML arrives, assets are already downloaded
6. Page renders instantly

### 3. Per-Page Configuration (Optional)

Configure hint priorities based on page content:

```ruby
class PostsController < ApplicationController
  # Image-heavy landing page - use low priority hints
  def index
    # Configure priorities first
    view_context.configure_early_hints(css: 'prefetch', js: 'prefetch')

    # Then send hints
    view_context.send_pack_early_hints('application', 'posts')

    # Finally, expensive work
    @posts = Post.all
  end

  # Interactive editor - use high priority hints
  def edit
    view_context.configure_early_hints(css: 'preload', js: 'preload')
    view_context.send_pack_early_hints('application', 'editor')
    @post = Post.find(params[:id])
  end
end
```

### 4. Dynamic Configuration

Configure hints based on runtime content:

```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])

    if @post.has_hero_video?
      # Video is LCP - don't compete with JS/CSS
      view_context.configure_early_hints(all: 'none')
    elsif @post.interactive?
      # JS needed for interactivity
      view_context.configure_early_hints(css: 'prefetch', js: 'preload')
    else
      # Standard blog post
      view_context.configure_early_hints(css: 'preload', js: 'prefetch')
    end

    # Send hints after configuring
    view_context.send_pack_early_hints('application', 'posts')
  end
end
```

### 5. Preloading Hero Images and Videos

Use Rails' built-in `preload_link_tag` to preload hero images, videos, and other LCP resources. Rails automatically sends these as early hints:

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <%= preload_link_tag image_path('hero.jpg'), as: 'image', type: 'image/jpeg' %>
    <%= preload_link_tag video_path('intro.mp4'), as: 'video', type: 'video/mp4' %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

**Dynamic preloading in views:**

```erb
<%# app/views/posts/show.html.erb %>
<% if @post.hero_image_url.present? %>
  <%= preload_link_tag @post.hero_image_url, as: 'image' %>
<% end %>
```

**Benefits:**

- ✅ Standard Rails API - no custom Shakapacker code needed
- ✅ Automatically sends early hints when server supports it
- ✅ Works with `image_path`, `video_path`, `asset_path` helpers
- ✅ Supports all standard attributes: `as`, `type`, `crossorigin`, `integrity`

**When to preload images/videos:**

- Hero images that are LCP (Largest Contentful Paint) elements
- Above-the-fold images critical for initial render
- Background videos that play on page load

**Performance tip:** Don't over-preload! Each preload competes for bandwidth. Focus only on critical resources that improve LCP.

See [Rails preload_link_tag docs](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-preload_link_tag) for full API.

## Controller Configuration

#### Skip Early Hints Entirely

```ruby
class ApiController < ApplicationController
  # Skip for entire controller
  skip_send_pack_early_hints
end

class PostsController < ApplicationController
  # Skip for specific actions
  skip_send_pack_early_hints only: [:api_endpoint, :feed]
end
```

#### Configure Per Action (Class Method)

```ruby
class PostsController < ApplicationController
  # Configure specific actions
  configure_pack_early_hints only: [:show], css: 'prefetch', js: 'preload'
  configure_pack_early_hints only: [:gallery], css: 'none', js: 'none'

  # Use 'all' shortcut
  configure_pack_early_hints only: [:about], all: 'prefetch'

  # Mix general and specific (specific wins)
  configure_pack_early_hints only: [:dashboard], all: 'preload', css: 'prefetch'
  # Result: css='prefetch', js='preload'
end
```

#### Configure in Action Method

```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])

    # Configure based on runtime logic
    if @post.video_content?
      view_context.configure_early_hints(css: 'none', js: 'none')
    end

    # Send hints BEFORE expensive work
    view_context.send_pack_early_hints('application', 'posts')

    # Expensive work happens while browser downloads
    # ...
  end
end
```

#### Configure in Before Action

```ruby
class PostsController < ApplicationController
  before_action :optimize_for_images, only: [:gallery, :portfolio]

  def gallery
    # Send hints early
    view_context.send_pack_early_hints('application', 'gallery')

    # Expensive work
    @images = Image.includes(:tags).all
  end

  private

  def optimize_for_images
    view_context.configure_early_hints(css: 'prefetch', js: 'prefetch')
  end
end
```

## Configuration Precedence

Settings are applied in this order (later overrides earlier):

1. **Global** (shakapacker.yml) - project defaults
2. **Controller class** (configure_pack_early_hints) - per-action defaults
3. **Manual call** (send_pack_early_hints in view) - explicit override

Within a single configuration, `all:` is applied first, then specific `css:` and `js:` values override it.

## Usage Examples by Scenario

### Scenario 1: Image-Heavy Landing Page

**Problem**: Large hero image is LCP, JS/CSS hints compete for bandwidth and delay image loading

```ruby
class HomeController < ApplicationController
  def index
    # Configure low priority hints to save bandwidth for hero image
    view_context.configure_early_hints(css: 'none', js: 'prefetch')

    # Send hints
    view_context.send_pack_early_hints('application')

    # Expensive work
    @featured_posts = Post.featured.limit(5)
  end
end
```

**Why**:

- `css: 'none'` - No hint sent, CSS discovered normally (saves bandwidth)
- `js: 'prefetch'` - Low priority hint, JS downloads when idle (doesn't compete)
- **Result**: Hero image gets full bandwidth priority for better LCP

### Scenario 2: Interactive Dashboard

**Problem**: App is useless without JavaScript

```ruby
class DashboardController < ApplicationController
  def index
    # JS is critical - use high priority hints
    view_context.configure_early_hints(all: 'preload')
    view_context.send_pack_early_hints('application', 'dashboard')

    # Expensive analytics query
    @metrics = Metric.calculate_dashboard_data
  end
end
```

**Why**: Fast JS load is more important than LCP

### Scenario 3: Blog with Varied Content

**Problem**: Article pages have images, index doesn't

```ruby
class ArticlesController < ApplicationController
  def index
    # Index: no large images - use high priority hints
    view_context.configure_early_hints(css: 'preload', js: 'preload')
    view_context.send_pack_early_hints('application', 'articles')

    @articles = Article.published.paginate(page: params[:page])
  end

  def show
    # Show: featured images - use low priority hints
    view_context.configure_early_hints(css: 'prefetch', js: 'prefetch')
    view_context.send_pack_early_hints('application', 'articles')

    @article = Article.find(params[:id])
  end
end
```

**Why**: Different pages have different performance needs

### Scenario 4: Mixed Content Types

**Problem**: Posts contain videos, images, or interactive content

```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])

    case @post.content_type
    when 'video'
      # Video is LCP
      configure_pack_early_hints all: 'none'
    when 'interactive'
      # JS needed immediately
      configure_pack_early_hints css: 'prefetch', js: 'preload'
    when 'image_gallery'
      # Images are LCP
      configure_pack_early_hints all: 'prefetch'
    else
      # Standard text post
      configure_pack_early_hints css: 'preload', js: 'prefetch'
    end
  end
end
```

**Why**: Dynamic configuration based on actual content

### Scenario 5: E-commerce Product Pages

**Problem**: Product images are critical, but checkout needs JS

```ruby
class ProductsController < ApplicationController
  # Product page: images are critical
  configure_pack_early_hints only: [:show], css: 'prefetch', js: 'prefetch'

  # Checkout: form validation needs JS
  configure_pack_early_hints only: [:checkout], css: 'preload', js: 'preload'
end
```

**Why**: Shopping vs checkout have different needs

## How It Works

Shakapacker automatically sends early hints after your views render:

```text
1. Request arrives
2. Controller action runs      → Database queries, business logic
3. Views render               → append_javascript_pack_tag('admin')
4. Layout renders             → javascript_pack_tag, stylesheet_pack_tag
5. after_action hook          → Reads configuration and queues
6. HTTP 103 sent              → rel=preload or rel=prefetch based on config
7. HTTP 200 sent              → Full HTML response
```

**Important timing note**: HTTP 103 is sent after rendering completes but before the final HTTP 200 response. This means:

- ✅ **Benefits**: Browser starts downloading assets while the server transmits the final HTML response
- ❌ **Limitations**: Does NOT help during database queries or view rendering—only helps with network transfer time
- 💡 **Best for**: Pages with large HTML responses where asset downloads can happen in parallel with HTML transmission

## Advanced: Manual Control

Most apps should use controller configuration. Use manual control for view-specific logic:

```erb
<%# app/views/layouts/application.html.erb %>
<% send_pack_early_hints css: 'prefetch', js: 'preload' %>

<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

**Per-tag override:**

```erb
<%= javascript_pack_tag 'application',
    early_hints: { css: 'preload', js: 'prefetch' } %>
```

**Use cases:** Layout-specific optimizations, conditional hints based on view variables, A/B testing

## Requirements

- **Rails 5.2+** (for `request.send_early_hints` support)
- **Web server with HTTP/2 and early hints:**
  - Puma 5+ ✅
  - nginx 1.13+ with ngx_http_v2_module ✅
  - Other HTTP/2 servers with early hints support
- **Modern browsers:**
  - Chrome/Edge/Firefox 103+ ✅
  - Safari 16.4+ ✅

If requirements not met, feature gracefully degrades with no errors.

## Quick Reference

### Priority levels and when to use each:

- **`preload`** (Prioritize): Critical assets on text-heavy pages, SPAs, pages without large images
- **`prefetch`** (De-prioritize): Non-critical assets, pages with large LCP images/videos (downloads when idle)
- **`none`** (Default behavior): Image/video-heavy pages, API endpoints, SSR pages (no hint sent)

### Testing checklist:

1. Measure LCP with Chrome DevTools Performance tab
2. Test on real mobile devices
3. A/B test configurations with real user data
4. Monitor field data with RUM tools
5. Test each page type separately

## Troubleshooting

For comprehensive testing instructions including browser DevTools and curl methods, see the [Feature Testing Guide: HTTP 103 Early Hints](feature_testing.md#http-103-early-hints).

### Debug Mode

Enable debug mode to see what early hints are being sent (or why they weren't sent):

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
    debug: true # Outputs debug info as HTML comments
```

Debug mode adds HTML comments to your page showing:

- Whether hints were sent or skipped
- What pack names were processed
- What Link headers were sent
- HTTP/2 support status

View page source and look for `<!-- Shakapacker Early Hints Debug -->` comments.

**Early hints not appearing:**

- **Enable debug mode first** to see what's happening
- **Check for proxy stripping**: If debug shows hints sent but curl/DevTools don't show `HTTP/2 103`, your reverse proxy or CDN (Control Plane, Cloudflare, AWS ALB/ELB, nginx) is likely stripping 103 responses. This is the **most common cause** of "missing" early hints
- Check `early_hints: enabled: true` in shakapacker.yml
- Verify HTTP/2 server (Puma 5+, nginx 1.13+)
- Check Network tab shows "h2" protocol and 103 status

**Reverse proxy stripping 103 responses:**

If debug mode shows hints are sent but they're not reaching clients, configure your proxy:

- **nginx**: Add `proxy_pass_header Link;` to pass through early hints (nginx 1.13+)
- **Cloudflare**: Enable "Early Hints" in Speed > Optimization (paid plans only)
- **AWS ALB/ELB**: Not supported - ALBs strip 103 responses. Workaround: skip ALB or use CloudFront
- **Control Plane**: Appears to strip 103 - Contact their support if you need early hints

See the [Feature Testing Guide](feature_testing.md#troubleshooting-early-hints) for detailed proxy configuration examples.

**Performance got worse:**

- Page likely has large images/videos as LCP
- Try `css: 'prefetch', js: 'prefetch'` or `all: 'none'`
- Measure LCP before and after changes

**Wrong hints sent:**

- Check configuration precedence (global → controller → manual)
- Verify values are strings: `'preload'` not `:preload`
- Check for typos (case-sensitive)

## References

### Shakapacker Documentation

- [Feature Testing Guide: HTTP 103 Early Hints](feature_testing.md#http-103-early-hints) - Detailed testing instructions with browser DevTools and curl

### External Resources

- [Rails API: send_early_hints](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-send_early_hints)
- [RFC 8297: HTTP Early Hints](https://datatracker.ietf.org/doc/html/rfc8297)
- [MDN: rel=preload vs rel=prefetch](https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel)
- [Web.dev: Optimize LCP](https://web.dev/optimize-lcp/)
- [HTTP 103 Explained](https://http.dev/103)
