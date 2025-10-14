# Upgrading to HTTP 103 Early Hints

This guide helps you add HTTP 103 Early Hints support to your existing Shakapacker project with minimal changes.

## What are Early Hints?

HTTP 103 Early Hints allows browsers to start downloading critical assets (JS, CSS) **while** Rails is still rendering your views. This can significantly improve page load performance, especially if you have expensive database queries or complex view rendering.

## Quick Start (Zero Configuration)

The easiest way to enable early hints:

### 1. Enable in Configuration

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
    default_packs: ["application"] # Your main pack(s)
    include_css: true
    include_js: true
```

### 2. Add One Line to Your Layout

**Option A: At the very top (optimal performance)**

```erb
<% send_pack_early_hints %>
<!DOCTYPE html>
<html>
  <head>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

**Option B: Inside `<head>` (still good performance)**

```erb
<!DOCTYPE html>
<html>
  <head>
    <% send_pack_early_hints %>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

That's it! No need to duplicate pack names - `send_pack_early_hints` uses `default_packs` from your config.

## Advanced: Controller-Level Early Hints

For maximum performance benefit (sending hints **before** expensive queries), add a `before_action`:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :send_early_hints_for_assets

  private

  def send_early_hints_for_assets
    # Sends early hints BEFORE any view rendering or database queries
    view_context.send_pack_early_hints
  end
end
```

This is especially beneficial if your views make expensive database queries.

## Multiple Packs

If different controllers use different packs:

### Configuration Approach

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
    default_packs: ["application", "admin", "marketing"] # All packs you use
```

### Per-Controller Approach

```ruby
class AdminController < ApplicationController
  before_action :send_admin_early_hints

  private

  def send_admin_early_hints
    view_context.send_pack_early_hints('admin')
  end
end
```

### Per-Layout Approach

```erb
<%# layouts/admin.html.erb %>
<% send_pack_early_hints 'admin' %>
<!DOCTYPE html>
...
```

## Requirements

- **Rails 5.2+** (for `request.send_early_hints` support)
- **Web server with HTTP/2 and early hints:**
  - Puma 5+ ✅
  - nginx 1.13+ with ngx_http_v2_module ✅
  - Other HTTP/2 servers with early hints support

## Verification

To verify early hints are working:

1. **Check server logs** - Should see HTTP 103 responses
2. **Chrome DevTools** - Network tab shows requests starting earlier
3. **WebPageTest** - Shows assets downloading during "server think time"

## Rollback

If you need to disable:

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: false
```

Or simply remove `<% send_pack_early_hints %>` from your layout.

## Performance Tips

1. **Enable in production only** - Development doesn't benefit much
2. **Place helper at top of layout** - Sends hints as early as possible
3. **Use controller before_action** - Sends hints before expensive queries
4. **Monitor performance** - Use APM to measure impact

## Troubleshooting

**Early hints not being sent?**

- Check Rails version >= 5.2
- Verify server supports HTTP/2 and early hints
- Check logs for HTTP 103 responses
- Ensure `enabled: true` in config

**Wrong assets being preloaded?**

- Review `default_packs` configuration
- Or explicitly specify packs: `<% send_pack_early_hints 'your-pack' %>`

**No performance improvement?**

- Early hints work best with:
  - Slow server responses (expensive queries/rendering)
  - Large assets
  - High network latency
- May not help much with very fast responses

## Examples

### Standard Rails App

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
    default_packs: ["application"]
```

```erb
<%# app/views/layouts/application.html.erb %>
<% send_pack_early_hints %>
<!DOCTYPE html>
<html>
  <head>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

### Multi-Pack App

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
    default_packs: ["application", "admin"]
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :send_early_hints

  private

  def send_early_hints
    view_context.send_pack_early_hints
  end
end
```

### App with Expensive Queries

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :send_early_hints

  def show
    # Expensive query - but browser is already downloading assets!
    @data = User.includes(:posts, :comments, :likes)
                .where(active: true)
                .order(created_at: :desc)
                .limit(100)
  end

  private

  def send_early_hints
    view_context.send_pack_early_hints
  end
end
```

## Further Reading

- [Rails API: send_early_hints](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-send_early_hints)
- [RFC 8297: HTTP Early Hints](https://datatracker.ietf.org/doc/html/rfc8297)
- [Eileen Codes: HTTP/2 Early Hints](https://eileencodes.com/posts/http2-early-hints/)
