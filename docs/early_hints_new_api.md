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
    enabled: true    # Master switch (default: false)
    debug: true      # Show HTML comments with debug info (default: false)
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

## Requirements

- Rails 5.2+ (for `request.send_early_hints`)
- HTTP/2 web server (Puma 5+, nginx 1.13+)
- Modern browsers (Chrome/Firefox 103+, Safari 16.4+)

Gracefully degrades if not supported.
