# HTTP 103 Early Hints - New API

## Quick Start

### Pattern 1: Automatic (Default)

By default, `javascript_pack_tag` and `stylesheet_pack_tag` automatically send early hints when early hints are enabled in config:

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
```

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <%# Automatically sends early hints for application pack CSS %>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= yield %>
    <%# Automatically sends early hints for application pack JS %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

**How it works:**

- When `stylesheet_pack_tag` is called, it automatically sends CSS early hints
- When `javascript_pack_tag` is called, it automatically sends JS early hints
- Combines queue (from `append_*_pack_tag`) + direct args
- Default: `rel=preload` for all packs

---

## Pattern 2: Per-Pack Customization in Layout

Customize hint handling per pack using a hash:

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <%# Mixed handling: preload application, prefetch vendor %>
    <%= stylesheet_pack_tag 'application', 'vendor',
          early_hints: { 'application' => 'preload', 'vendor' => 'prefetch' } %>
  </head>
  <body>
    <%= yield %>
    <%# Disable early hints for this tag %>
    <%= javascript_pack_tag 'application', early_hints: false %>
  </body>
</html>
```

**Options:**

- `"preload"` - High priority (default)
- `"prefetch"` - Low priority
- `false` or `"none"` - Disabled

---

## Pattern 3: Controller Override (Before Expensive Work)

Send hints manually in controller BEFORE expensive work to maximize parallelism:

```ruby
class PostsController < ApplicationController
  def show
    # Send hints BEFORE expensive work
    send_pack_early_hints({
      "application" => { js: "preload", css: "preload" },
      "admin" => { js: "prefetch", css: "none" }
    })

    # Browser now downloading assets while we do expensive work
    @post = Post.includes(:comments, :author, :tags).find(params[:id])
    @related = @post.find_related_posts(limit: 10)  # Expensive query
    # ... more work ...
  end
end
```

**Timeline:**

1. Request arrives
2. `send_pack_early_hints` called → HTTP 103 sent immediately
3. Browser starts downloading assets
4. Rails continues with expensive queries (IN PARALLEL with browser downloads)
5. View renders
6. HTTP 200 sent with full HTML
7. Assets already downloaded = faster page load

**Benefits:**

- ✅ Parallelizes browser downloads with server processing
- ✅ Can save 200-500ms on pages with slow controllers
- ✅ Most valuable for pages with expensive queries/API calls

---

## Pattern 4: View Override

Views can use `append_*_pack_tag` to add packs dynamically:

```erb
<%# app/views/posts/edit.html.erb %>
<% append_javascript_pack_tag 'admin_tools' %>

<div class="post-editor">
  <%# ... editor UI ... %>
</div>
```

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= yield %>  <%# View has run, admin_tools added to queue %>

    <%# Sends hints for BOTH application + admin_tools %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

**How it works:**

- Views call `append_javascript_pack_tag('admin_tools')`
- Layout calls `javascript_pack_tag('application')`
- Helper combines: `['application', 'admin_tools']`
- Sends hints for ALL packs automatically

---

## Configuration

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true # Master switch (default: false)
    debug: true # Show HTML comments with debug info (default: false)
```

---

## Duplicate Prevention

Hints are automatically prevented from being sent twice:

```ruby
# Controller
def show
  send_pack_early_hints({ "application" => { js: "preload", css: "preload" } })
  # ... expensive work ...
end
```

```erb
<%# Layout %>
<%= javascript_pack_tag 'application' %>
<%# Won't send duplicate hint - already sent in controller %>
```

**How it works:**

- Tracks which packs have sent JS hints: `@early_hints_javascript = {}`
- Tracks which packs have sent CSS hints: `@early_hints_stylesheets = {}`
- Skips sending hints for packs already sent

---

## When to Use Each Pattern

### Pattern 1 (Automatic) - Best for:

- Simple apps with consistent performance
- Small/medium JS bundles (<500KB)
- Fast controllers (<100ms)

### Pattern 2 (Per-Pack) - Best for:

- Mixed vendor bundles (preload critical, prefetch non-critical)
- Different handling for different packs
- Layout-specific optimizations

### Pattern 3 (Controller) - Best for:

- Slow controllers with expensive queries (>300ms)
- Large JS bundles (>500KB)
- APIs calls in controller
- Maximum parallelism needed

### Pattern 4 (View Override) - Best for:

- Admin sections with extra packs
- Feature flags determining packs
- Page-specific bundles

---

## Full Example: Mixed Patterns

```ruby
# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  def index
    # Fast controller, use automatic hints
  end

  def show
    # Slow controller, send hints early
    send_pack_early_hints({
      "application" => { js: "preload", css: "preload" }
    })

    # Expensive work happens in parallel with browser downloads
    @post = Post.includes(:comments, :author).find(params[:id])
  end
end
```

```erb
<%# app/views/posts/show.html.erb %>
<% if current_user&.admin? %>
  <% append_javascript_pack_tag 'admin_tools' %>
<% end %>
```

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <%# Automatic CSS hints for application %>
    <%= stylesheet_pack_tag 'application' %>
  </head>
  <body>
    <%= yield %>

    <%# Automatic JS hints for application + admin_tools (if appended) %>
    <%# Won't duplicate hints already sent in controller %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

---

## Preloading Non-Pack Assets (Images, Videos, Fonts)

**Shakapacker's early hints are for pack assets (JS/CSS bundles).** For non-pack assets like hero images, videos, and fonts, you have two options:

### Option 1: Manual Early Hints (For LCP/Critical Assets)

**IMPORTANT:** Browsers only process the FIRST HTTP 103 response. If you need both pack assets AND images/videos in early hints, you must send them together in ONE call.

```ruby
class PostsController < ApplicationController
  before_action :send_critical_early_hints, only: [:show]

  private

  def send_critical_early_hints
    # Build all early hints in ONE call (packs + images)
    links = []

    # Pack assets (using Shakapacker manifest)
    js_path = "/packs/#{Shakapacker.manifest.lookup!('application.js')}"
    css_path = "/packs/#{Shakapacker.manifest.lookup!('application.css')}"
    links << "<#{js_path}>; rel=preload; as=script"
    links << "<#{css_path}>; rel=preload; as=style"

    # Critical images (for LCP - Largest Contentful Paint)
    links << "<#{view_context.asset_path('hero.jpg')}>; rel=preload; as=image"

    # Send ONE HTTP 103 response with all hints
    request.send_early_hints("Link" => links.join(", "))
  end

  def show
    # Early hints already sent, browser downloading assets in parallel
    @post = Post.find(params[:id])
  end
end
```

**When to use:**

- Pages with hero images affecting LCP (Largest Contentful Paint)
- Videos that must load quickly
- Critical fonts not in pack bundles

### Option 2: HTML Preload Links (Simpler, No Early Hints)

Use Rails' `preload_link_tag` to add `<link rel="preload">` in the HTML:

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <%# Shakapacker sends early hints for packs %>
    <%= stylesheet_pack_tag 'application' %>

    <%# Preload link in HTML (no HTTP 103, but still speeds up loading) %>
    <%= preload_link_tag asset_path('hero.jpg'), as: 'image' %>
  </head>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
```

**When to use:**

- Images that don't affect LCP
- Less critical assets
- Simpler implementation preferred

**Note:** `preload_link_tag` only adds HTML `<link>` tags - it does NOT send HTTP 103 Early Hints.

---

## Requirements & Limitations

**IMPORTANT:** Before implementing Early Hints, understand these limitations:

### Architecture: Proxy Required for HTTP/2

**Standard production architecture for Early Hints:**

```
Browser (HTTP/2)
    ↓
Proxy (Thruster, nginx, CDN, etc.)
    ├─ Receives HTTP/2
    ├─ Translates to HTTP/1.1
    ↓
Puma (HTTP/1.1)
    ├─ Sends HTTP/1.1 103 Early Hints ✅
    ├─ Sends HTTP/1.1 200 OK
    ↓
Proxy
    ├─ Translates to HTTP/2
    ↓
Browser (HTTP/2 103) ✅
```

**Key insight**: Puma always runs HTTP/1.1. The proxy handles HTTP/2 for external clients.

### Puma Limitation: HTTP/1.1 Only

**Puma ONLY supports HTTP/1.1 Early Hints** (not HTTP/2). This is a Rack/Puma limitation, and **there are no plans to add HTTP/2 support to Puma**.

- ✅ **Works**: Puma 5+ with HTTP/1.1
- ❌ **Doesn't work**: Puma with HTTP/2 (h2)
- ✅ **Solution**: Use a proxy in front of Puma (Thruster, nginx, etc.)

**This is the expected architecture** - there's always something in front of Puma to handle HTTP/2 translation in production.

### Browser Behavior

**Browsers only process the FIRST `HTTP/1.1 103` response.**

- Shakapacker sends ONE 103 response with ALL hints (JS + CSS combined)
- Subsequent 103 responses are ignored by browsers
- This is by design per the HTTP 103 spec

### Minimum Requirements

- Rails 5.2+ (for `request.send_early_hints`)
- Puma 5+ (for HTTP/1.1 103 support)
- Modern browsers (Chrome/Firefox 103+, Safari 16.4+)

Gracefully degrades if not supported.

### Testing Locally

**Step 1: Enable early hints in your test environment**

```yaml
# config/shakapacker.yml
development:  # or production
  early_hints:
    enabled: true
    debug: true  # Shows hints in HTML comments
```

**Step 2: Start Rails in the environment you configured**

```bash
# Option 1: Test in development (if enabled above)
rails server

# Option 2: Test in production mode locally (more realistic)
RAILS_ENV=production rails assets:precompile  # Compile assets first
RAILS_ENV=production rails server
```

**Step 3: Test with curl**

```bash
# Use HTTP/1.1 (NOT HTTP/2)
curl -v http://localhost:3000/

# Look for this in output:
< HTTP/1.1 103 Early Hints
< link: </packs/application-abc123.js>; rel=preload; as=script
< link: </packs/application-abc123.css>; rel=preload; as=style
<
< HTTP/1.1 200 OK
```

**Important notes:**

- Use `http://` (not `https://`) for local testing
- Puma dev mode uses HTTP/1.1 (not HTTP/2)
- Test in production mode for realistic asset paths with content hashes
- Early hints must be `enabled: true` for the environment you're testing

### Production Setup

#### Thruster (Rails 8+ Default)

**Recommended**: Use [Thruster](https://github.com/basecamp/thruster) in front of Puma (Rails 8 default).

Thruster handles HTTP/2 → HTTP/1.1 translation automatically. No configuration needed - Early Hints just work.

```dockerfile
# Dockerfile (Rails 8 default)
CMD ["bundle", "exec", "thrust", "./bin/rails", "server"]
```

Thruster will:

1. Receive HTTP/2 requests from browsers
2. Translate to HTTP/1.1 for Puma
3. Pass through HTTP/1.1 103 Early Hints from Puma
4. Translate to HTTP/2 103 for browsers

#### Control Plane

**CRITICAL**: Set workload protocol to `HTTP` (NOT `HTTP2`):

```
Protocol: HTTP   ← Use HTTP/1.1 for Puma container
Port: 3000
```

**Why**: Puma ONLY supports HTTP/1.1 Early Hints. If you set protocol to `HTTP2`, Early Hints will NOT work.

Control Plane's load balancer handles HTTP/2 translation automatically:

1. Browser → Control Plane LB (HTTP/2)
2. Control Plane LB → Puma (HTTP/1.1)
3. Puma → Control Plane LB (HTTP/1.1 103)
4. Control Plane LB → Browser (HTTP/2 103)

#### nginx (Self-Hosted)

If you want HTTP/2 in production with self-hosted nginx:

```nginx
# /etc/nginx/sites-available/myapp
upstream puma {
  server unix:///var/www/myapp/tmp/sockets/puma.sock;
}

server {
  listen 443 ssl http2;
  server_name example.com;

  # SSL certificates
  ssl_certificate /path/to/cert.pem;
  ssl_certificate_key /path/to/key.pem;

  location / {
    proxy_pass http://puma;  # Puma uses HTTP/1.1
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # CRITICAL: Pass through Early Hints from Puma
    proxy_pass_header Link;
  }
}
```

nginx will:

1. Receive HTTP/2 request from browser
2. Forward as HTTP/1.1 to Puma
3. Receive HTTP/1.1 103 from Puma
4. Translate to HTTP/2 103 for browser

---

## Troubleshooting

### Early Hints Not Appearing

**Step 1: Enable debug mode to see what Puma is sending**

```yaml
# config/shakapacker.yml
development:
  early_hints:
    enabled: true
    debug: true  # Shows hints in HTML comments
```

Reload your page and check the HTML source for comments like:

```html
<!-- Early hints sent (JS): application=preload -->
<!-- Early hints sent (CSS): application=preload -->
```

**If debug shows hints are sent:**

The issue is with your **proxy/infrastructure**, not Shakapacker. Proceed to Step 2.

**If debug shows NO hints sent:**

Check your config:

- `early_hints.enabled: true` in `config/shakapacker.yml`
- Rails 5.2+
- Puma 5+

---

**Step 2: Check if your proxy is stripping 103 responses**

This is the **most common cause** of missing early hints.

Test with curl against your local Puma (HTTP/1.1):

```bash
# Direct to Puma (should work)
curl -v http://localhost:3000/

# Look for:
< HTTP/1.1 103 Early Hints
< link: </packs/application.js>; rel=preload; as=script
<
< HTTP/1.1 200 OK
```

If you see the 103 response, Puma is working correctly.

---

**Step 3: Common proxy issues**

#### Control Plane

**Fix:** Set workload protocol to `HTTP` (NOT `HTTP2`):

```
Protocol: HTTP   ← Must be HTTP/1.1
Port: 3000
```

Control Plane's load balancer handles HTTP/2 translation. If you set protocol to `HTTP2`, early hints will NOT work.

#### AWS ALB/ELB

**Not supported** - ALBs strip 103 responses entirely. No workaround except:

- Skip ALB (not recommended)
- Use CloudFront in front (CloudFront supports early hints)

#### Cloudflare

Enable "Early Hints" in dashboard:

```
Speed > Optimization > Early Hints: ON
```

**Note:** Paid plans only (Pro/Business/Enterprise).

#### nginx

nginx 1.13+ passes 103 responses automatically. Ensure you're using HTTP/2:

```nginx
server {
  listen 443 ssl http2;  # Enable HTTP/2

  location / {
    proxy_pass http://puma;  # Puma uses HTTP/1.1
    proxy_http_version 1.1;  # Required for Puma
  }
}
```

No special configuration needed - nginx automatically translates HTTP/1.1 103 to HTTP/2 103.

#### Thruster (Rails 8+)

Thruster handles HTTP/2 → HTTP/1.1 translation automatically. Early hints just work. No configuration needed.

---

### Debugging Checklist

1. ✅ **Config enabled:** `early_hints.enabled: true` in `shakapacker.yml`
2. ✅ **Debug mode on:** See HTML comments confirming hints sent
3. ✅ **Puma 5+:** Early hints require Puma 5+
4. ✅ **Rails 5.2+:** `request.send_early_hints` API available
5. ✅ **Architecture:** Proxy in front of Puma (Thruster, nginx, Control Plane)
6. ✅ **Puma protocol:** Always HTTP/1.1 (never HTTP/2)
7. ✅ **Proxy protocol:** HTTP/2 to browser, HTTP/1.1 to Puma
8. ✅ **Browser support:** Chrome 103+, Firefox 103+, Safari 16.4+

---

### Performance Got Worse?

If enabling early hints **decreased** performance:

**Likely cause:** Page has large images/videos as LCP (Largest Contentful Paint).

Preloading large JS bundles can delay image downloads, hurting LCP.

**Fix:**

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true
    css: "prefetch"  # Lower priority
    js: "prefetch"   # Lower priority
```

Or disable entirely and use HTML `preload_link_tag` for images instead.

---

### Reference

- [Rails 103 Early Hints Analysis](https://island94.org/2025/10/rails-103-early-hints-could-be-better-maybe-doesn-t-matter)
