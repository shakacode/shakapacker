# Add HTTP 103 Early Hints Support

## Summary

Adds HTTP 103 Early Hints support to Shakapacker, allowing browsers to preload critical assets while Rails is processing or rendering, significantly improving perceived page load performance.

## ⚠️ BREAKING CHANGE

**The automatic `after_action` early hints feature has been removed.**

Early hints must now be **explicitly called** in your application code using one of two patterns:

1. At the top of layouts (recommended - simpler)
2. In controller actions before expensive work (for heavy queries)

### Why the Breaking Change?

The automatic `after_action` approach was fundamentally broken:

- Ran AFTER view rendering completed
- By that time, the response was ready - no more "think time" for parallelism
- Defeated the entire purpose of "early" hints
- Browser couldn't start downloading until all work was done

Example of what was broken:

```ruby
# This was happening automatically but WRONGLY:
after_action :send_pack_early_hints_automatically
# ↑ Runs after views rendered - TOO LATE!
```

## New Usage Patterns

### Pattern 1: In Layout (RECOMMENDED - Simpler)

```erb
<%# app/views/layouts/application.html.erb %>
<% send_pack_early_hints 'application' %>
<!DOCTYPE html>
<html>
  <head>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= yield %>  <%# Browser downloads while views render %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

**Timeline:**

1. Controller finishes
2. Layout starts rendering → `send_pack_early_hints` called
3. HTTP 103 sent → Browser starts downloading
4. Rails renders rest of layout/views **while browser downloads**
5. HTTP 200 sent → Assets already downloaded!

**Parallelism:** Browser downloading ↔ Rails rendering views/partials

**Use when:** Most cases. Simple and effective.

### Pattern 2: In Controller (For Heavy Queries)

```ruby
class PostsController < ApplicationController
  def index
    # Send hints BEFORE expensive work
    view_context.send_pack_early_hints('application', 'posts')

    # Browser downloads while controller works
    @posts = Post.expensive_query      # 200ms
    @stats = Statistics.calculate      # 150ms
    # Total: 350ms of parallel download time!
  end
end
```

**Timeline:**

1. Controller starts
2. `send_pack_early_hints` called → HTTP 103 sent
3. Browser starts downloading **while controller processes**
4. Controller finishes, views render
5. HTTP 200 sent

**Parallelism:** Browser downloading ↔ Controller queries/API calls

**Use when:** Controller has significant work (>100ms). Maximizes benefit.

## Features

### Configuration

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true # Master switch
    css: "preload" # 'preload' | 'prefetch' | 'none'
    js: "preload" # 'preload' | 'prefetch' | 'none'
    debug: false # Enable to see hints as HTML comments
```

### Debug Mode

Enable `debug: true` to see what hints were sent (or why they were skipped) as HTML comments:

```html
<!-- Shakapacker Early Hints Debug -->
<!-- Status: SENT -->
<!-- HTTP/2 Support: YES (https) -->
<!-- Packs: application -->
<!-- Links Sent: -->
<!--   </packs/application-abc123.js>; rel=preload; as=script... -->
<!-- -->
```

### Per-Page Configuration

```ruby
class PostsController < ApplicationController
  def show
    # Configure priority based on content
    if @post.has_hero_video?
      view_context.configure_early_hints(all: 'none')
    else
      view_context.configure_early_hints(css: 'preload', js: 'prefetch')
    end

    view_context.send_pack_early_hints('application', 'posts')
  end
end
```

### Priority Levels

- **`preload`** - High priority, downloads immediately (for critical assets)
- **`prefetch`** - Low priority, downloads when idle (for non-critical assets)
- **`none`** - No hint sent, discovered during HTML parsing

## Requirements

- Rails 5.2+ (for `request.send_early_hints`)
- HTTP/2-capable server (Puma 5+, nginx 1.13+)
- Modern browsers (Chrome/Edge/Firefox 103+, Safari 16.4+)
- Gracefully degrades if not supported

## Testing

### With Browser DevTools

1. Enable early hints in config
2. Add `send_pack_early_hints` to layout or controller
3. Deploy to HTTPS environment with HTTP/2
4. Open DevTools → Network tab
5. Reload page
6. Look for `103 Early Hints` status (if proxy doesn't strip it)

### With Debug Mode

1. Enable `debug: true` in config
2. View page source
3. Look for `<!-- Shakapacker Early Hints Debug -->` comments in `<head>`

### Important Note About Reverse Proxies

**Many reverse proxies and CDNs strip HTTP/2 103 responses** before they reach clients:

- Control Plane (cpln.app) - strips 103
- AWS ALB/ELB - strips 103
- Some Cloudflare configurations
- nginx without explicit early hints support

**Solution:** Use debug mode to verify Rails is sending hints. Even if proxies strip 103, Rails still sends Link headers in the 200 response which browsers can use.

## Documentation

- **[Early Hints Guide](docs/early_hints.md)** - Complete guide with configuration, performance tips, and examples
- **[Feature Testing Guide](docs/feature_testing.md)** - How to verify early hints are working
- **[Testing Instructions](EARLY_HINTS_TESTING.md)** - For example app testing

## Performance Considerations

⚠️ **Important:** Early hints can improve OR hurt performance depending on content:

- **May help:** Interactive dashboards, SPAs, pages with fast rendering
- **May hurt:** Pages with large hero images/videos as LCP
- **Recommendation:** Test with real user data, configure per-page based on content

See the [Early Hints Guide](docs/early_hints.md) for detailed performance guidance.

## Migration Guide

### Before (Broken Automatic Approach)

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true # This enabled broken automatic behavior
```

```ruby
# Nothing in controller or views - hints sent automatically (but broken)
```

### After (Explicit Calls Required)

**Option A: Layout (Recommended)**

```erb
<%# app/views/layouts/application.html.erb %>
<% send_pack_early_hints 'application' %>
<!DOCTYPE html>
```

**Option B: Controller**

```ruby
class ApplicationController < ActionController::Base
  def index
    view_context.send_pack_early_hints('application')
    # ... rest of action
  end
end
```

## What Changed

**Removed:**

- Automatic `after_action :send_pack_early_hints_automatically`
- `skip_send_pack_early_hints` class method
- Queue collection from `append_*_pack_tag` helpers
- Misleading automatic behavior documentation

**Added:**

- Debug mode with HTML comment output
- Clear documentation of two usage patterns
- Timing explanations for each pattern
- Comprehensive testing guide
- Proxy stripping documentation

**Changed:**

- `send_pack_early_hints` now requires explicit pack names (no automatic queue collection)
- Documentation completely rewritten to show correct usage patterns

## Related Issues

Fixes the fundamental timing issue where early hints were sent too late to provide any benefit.

## Testing Checklist

- [x] Removed broken automatic after_action code
- [x] Updated helper documentation with correct patterns
- [x] Added debug mode for troubleshooting
- [x] Updated all documentation files
- [x] Created comprehensive testing guide
- [x] RuboCop passes
- [ ] Tests updated to verify new behavior
- [ ] Full test suite passes
