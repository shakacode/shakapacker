# Upgrading to HTTP 103 Early Hints

This guide helps you add HTTP 103 Early Hints support to your existing Shakapacker project with minimal changes.

## What are Early Hints?

HTTP 103 Early Hints allows browsers to start downloading critical assets (JS, CSS) **while** Rails is still rendering your views. This can significantly improve page load performance, especially if you have expensive database queries or complex view rendering.

## Quick Start - Works with Existing Code!

The easiest way to enable early hints - **no changes to your existing views needed**:

### 1. Enable in Configuration

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
    include_css: true
    include_js: true
```

### 2. Add One Line to Your Layout

```erb
<%# app/views/layouts/application.html.erb %>
<% send_pack_early_hints %>  <%# That's it! %>
<!DOCTYPE html>
<html>
  <head>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

**Done!** No pack names needed, works with your existing `append_javascript_pack_tag` calls.

## How It Works

The magic is in Rails' rendering order:

```
1. Views render     → append_javascript_pack_tag('admin')  [queues populate]
2. Layout renders   → send_pack_early_hints()              [reads queues!]
3. HTTP 103 sent    → Browser starts downloading
4. HTML renders     → javascript_pack_tag renders tags
```

When the layout starts rendering, your views have **already rendered**, so the pack queues are populated! `send_pack_early_hints()` with no arguments automatically discovers all packs.

## Example: Multi-Pack App

Your existing code probably looks like this:

```erb
<%# app/views/admin/dashboard.html.erb %>
<% append_javascript_pack_tag 'admin' %>
<% append_stylesheet_pack_tag 'admin' %>

<div class="admin-dashboard">
  ...
</div>
```

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
    <%= stylesheet_pack_tag 'application' %>
  </body>
</html>
```

Just add **one line** at the top of your layout:

```erb
<% send_pack_early_hints %>  <%# Automatically includes 'application' AND 'admin'! %>
<!DOCTYPE html>
...
```

## Advanced: Explicit Pack Names

If you know your pack names upfront (not using append/prepend pattern):

```erb
<% send_pack_early_hints 'application', 'admin' %>
<!DOCTYPE html>
...
```

## Advanced: Controller-Level (Before Expensive Queries)

For maximum performance, send hints **before** expensive queries:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :send_early_hints

  private

  def send_early_hints
    # Must specify packs - views haven't rendered yet!
    view_context.send_pack_early_hints('application')
  end
end
```

Or per-controller:

```ruby
class AdminController < ApplicationController
  before_action :send_admin_early_hints

  private

  def send_admin_early_hints
    view_context.send_pack_early_hints('admin')
  end
end
```

## Requirements

- **Rails 5.2+** (for `request.send_early_hints` support)
- **Web server with HTTP/2 and early hints:**
  - Puma 5+ ✅
  - nginx 1.13+ with ngx_http_v2_module ✅
  - Other HTTP/2 servers with early hints support

## Troubleshooting

**Early hints not working?**

- Verify Rails 5.2+ and server supports HTTP/2 + early hints
- Check `early_hints: enabled: true` in config
- Check logs for HTTP 103 responses

**Wrong assets preloaded?**

- If using zero-arg `send_pack_early_hints`, check what's in queues
- Or explicitly specify: `<% send_pack_early_hints 'your-pack' %>`

**No performance improvement?**

- Early hints help most with:
  - Slow server responses (expensive queries/rendering)
  - Large assets
  - High network latency
- May not help much with very fast responses

## Comparison: Before vs After

### Before

```erb
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

Timeline:

```
Request → Rails renders (3s) → Browser gets HTML → Browser downloads JS (2s) → Total: 5s
```

### After

```erb
<% send_pack_early_hints %>
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

Timeline:

```
Request → HTTP 103 sent → Browser downloads JS (2s running in parallel!)
       → Rails renders (3s) → Browser gets HTML → JS already downloaded! → Total: 3s
```

**2 second improvement!** Browser downloads assets **during** server think time.

## Further Reading

- [Rails API: send_early_hints](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-send_early_hints)
- [RFC 8297: HTTP Early Hints](https://datatracker.ietf.org/doc/html/rfc8297)
- [Eileen Codes: HTTP/2 Early Hints](https://eileencodes.com/posts/http2-early-hints/)
