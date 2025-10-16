# HTTP 103 Early Hints Guide

This guide shows you how to use HTTP 103 Early Hints with Shakapacker to optimize page load performance.

## What are Early Hints?

HTTP 103 Early Hints allows browsers to start downloading assets (JS, CSS) **while** Rails is still rendering your views. This may significantly improve page load performance or cause an equally significant regression, depending on the page's content.

⚠️ **Critical**: Preloading JavaScript may hurt your LCP (Largest Contentful Paint) metric if you have large images, videos, or other content that should load first. **Careful experimentation and performance measurement is required.**

### Preload vs Prefetch

- **`preload`** - High priority, browser downloads immediately. Use for critical assets needed for initial render.
- **`prefetch`** - Low priority, browser downloads when idle. Use for non-critical assets or future navigation.
- **`none`** - Skip hints entirely for this asset type.

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

### 2. Per-Page Configuration (Recommended)

Configure hints based on your page content:

```ruby
class PostsController < ApplicationController
  # Image-heavy landing page - don't compete with images
  configure_pack_early_hints only: [:index], css: 'none', js: 'prefetch'

  # Interactive post editor - JS is critical
  configure_pack_early_hints only: [:edit], css: 'preload', js: 'preload'

  # API endpoints - no hints needed
  skip_send_pack_early_hints only: [:api_data]
end
```

### 3. Dynamic Configuration

Configure based on content:

```ruby
class PostsController < ApplicationController
  def show
    @post = Post.find(params[:id])

    if @post.has_hero_video?
      # Video is LCP - don't compete
      configure_pack_early_hints all: 'none'
    elsif @post.interactive?
      # JS needed for interactivity
      configure_pack_early_hints css: 'prefetch', js: 'preload'
    else
      # Standard blog post
      configure_pack_early_hints css: 'preload', js: 'prefetch'
    end
  end
end
```

## Configuration Reference

### Global Configuration (shakapacker.yml)

```yaml
production:
  early_hints:
    enabled: true # Required - master switch
    css: "preload" # Optional - default: 'preload'
    js: "preload" # Optional - default: 'preload'
```

**Options:**

- `'preload'` - High priority (rel=preload)
- `'prefetch'` - Low priority (rel=prefetch)
- `'none'` - Disabled

### Controller Configuration

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
      configure_pack_early_hints css: 'none', js: 'none'
    end
  end
end
```

#### Configure in Before Action

```ruby
class PostsController < ApplicationController
  before_action :optimize_for_images, only: [:gallery, :portfolio]

  private

  def optimize_for_images
    configure_pack_early_hints css: 'prefetch', js: 'prefetch'
  end
end
```

### Manual Override (Views/Layouts)

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>

<%# Override for this specific request %>
<% send_pack_early_hints css: 'prefetch', js: 'none' %>
```

### Per-Tag Override

```erb
<%# In view - override just for this tag %>
<%= javascript_pack_tag 'application',
    early_hints: { css: 'preload', js: 'prefetch' } %>
```

## Configuration Precedence

Settings are applied in this order (later overrides earlier):

1. **Global** (shakapacker.yml) - project defaults
2. **Controller class** (configure_pack_early_hints) - per-action defaults
3. **Manual call** (send_pack_early_hints in view) - explicit override

Within a single configuration, `all:` is applied first, then specific `css:` and `js:` values override it.

## Usage Examples by Scenario

### Scenario 1: Image-Heavy Landing Page

**Problem**: Large hero image is LCP, JS/CSS preload delays it

```ruby
class HomeController < ApplicationController
  def index
    # Don't compete with hero image
    configure_pack_early_hints css: 'none', js: 'prefetch'
  end
end
```

**Why**: Prioritizes image loading for better LCP

### Scenario 2: Interactive Dashboard

**Problem**: App is useless without JavaScript

```ruby
class DashboardController < ApplicationController
  # JS is critical for all actions
  configure_pack_early_hints all: 'preload'
end
```

**Why**: Fast JS load is more important than LCP

### Scenario 3: Blog with Varied Content

**Problem**: Article pages have images, index doesn't

```ruby
class ArticlesController < ApplicationController
  # Index: no large images
  configure_pack_early_hints only: [:index], css: 'preload', js: 'preload'

  # Show: featured images
  configure_pack_early_hints only: [:show], css: 'prefetch', js: 'prefetch'
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

## Performance Decision Guide

### When to use `preload`

✅ **Use for critical assets:**

- CSS for above-the-fold content on text-heavy pages
- JavaScript required for initial interactivity
- Pages with no large images or videos
- SPAs where JS loads everything

### When to use `prefetch`

✅ **Use for non-critical assets:**

- CSS for below-the-fold content
- Enhancement JavaScript (analytics, widgets)
- Pages with large LCP images
- Content that works without JS initially

### When to use `none`

✅ **Use when hints hurt performance:**

- Image-heavy pages (hero images, galleries)
- Video landing pages
- SSR pages that work without JS
- API endpoints
- Pages optimized for LCP over interactivity

### Testing Recommendations

1. **Measure LCP**: Use Chrome DevTools Performance tab
2. **Test Real Devices**: Mobile performance differs significantly
3. **A/B Test**: Compare configurations with real user data
4. **Monitor Field Data**: Use RUM (Real User Monitoring)
5. **Test Per Page Type**: Don't assume one config fits all

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

**Important timing note**: HTTP 103 is sent AFTER rendering completes. This means:

- ✅ **Benefits**: Browser starts downloading before parsing HTML
- ❌ **Limitations**: Does NOT help during database queries or view rendering
- 💡 **Best for**: Pages where asset download time is the bottleneck, not server processing

## Advanced: Manual Control

Most apps should use automatic configuration. Manual control is for special cases:

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>

<%# Manual call - overrides automatic behavior %>
<% send_pack_early_hints css: 'prefetch', js: 'preload' %>
```

**When to use manual control:**

- Layout-specific optimizations
- Conditional hints based on view variables
- A/B testing different configurations

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

## Troubleshooting

### Early hints not appearing in DevTools

1. Check `early_hints: enabled: true` in shakapacker.yml
2. Verify server supports HTTP/2 and early hints (Puma 5+)
3. Check browser DevTools → Network → Protocol column shows "h2"
4. Look for 103 status code before main response

### Performance got worse

1. Check if page has large images/videos (likely LCP elements)
2. Try `css: 'prefetch', js: 'prefetch'` or `all: 'none'`
3. Measure LCP before and after with Chrome DevTools
4. Consider configuring per-page instead of globally

### Hints sent for wrong asset type

1. Check controller configuration precedence
2. Verify `css:` and `js:` values are strings: `'preload'` not `:preload`
3. Check for typos: `'preload'`, `'prefetch'`, `'none'` (case-sensitive)

## References

- [Rails API: send_early_hints](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-send_early_hints)
- [RFC 8297: HTTP Early Hints](https://datatracker.ietf.org/doc/html/rfc8297)
- [MDN: rel=preload vs rel=prefetch](https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel)
- [Web.dev: Optimize LCP](https://web.dev/optimize-lcp/)
- [HTTP 103 Explained](https://http.dev/103)
