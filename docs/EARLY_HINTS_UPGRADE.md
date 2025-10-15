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
    enabled: true # default: false - must be explicitly enabled
    include_css: true # default: true when enabled - preload CSS chunks
    include_js: true # default: true when enabled - preload JS chunks
```

**Configuration options explained:**

- **`enabled`**: Master switch. Set to `true` in production. Default: `false`
- **`include_css`**: Send early hints for CSS files. Default: `true`
  - Set to `false` if you don't use Shakapacker for CSS (e.g., using Rails asset pipeline for styles)
- **`include_js`**: Send early hints for JavaScript files. Default: `true`
  - Set to `false` if you only want to preload CSS (rare use case)

**Common configurations:**

```yaml
# Most common: Enable everything (recommended)
production:
  early_hints:
    enabled: true
    include_css: true
    include_js: true

# JavaScript only (if CSS comes from Rails asset pipeline)
production:
  early_hints:
    enabled: true
    include_css: false
    include_js: true

# CSS only (rare - only if you have critical CSS)
production:
  early_hints:
    enabled: true
    include_css: true
    include_js: false

# Disabled (default - no early hints sent)
production:
  early_hints:
    enabled: false
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

```text
1. Views render     → append_javascript_pack_tag('admin')  [queues populate]
2. Layout renders   → send_pack_early_hints()              [reads queues!]
3. HTTP 103 sent    → Browser starts downloading
4. HTML renders     → javascript_pack_tag renders tags
```

When the layout starts rendering, your views have **already rendered**, so the pack queues are populated! `send_pack_early_hints()` with no arguments automatically discovers all packs.

## Example: Multi-Pack App

Your existing view code probably looks like this:

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

## Placement Matters!

`send_pack_early_hints` must be called **AFTER** `yield` in your layout (or at the very end, after all pack helpers):

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>  <%# Views render first and populate queues %>
  </body>
</html>
<% send_pack_early_hints %>  <%# NOW it can read the queues! %>
```

**Why?** Rails renders views first, then the layout. If you call `send_pack_early_hints` before `yield`, the queues will be empty.

## Advanced: Explicit Pack Names (Rarely Needed)

**Most apps should skip this section** - the zero-argument form is recommended.

### When NOT Using Append/Prepend Pattern

If you're **not** using `append_javascript_pack_tag` or `append_stylesheet_pack_tag` (calling `javascript_pack_tag` directly in layout), you can specify pack names explicitly:

```erb
<%# app/views/layouts/application.html.erb %>
<% send_pack_early_hints 'application', 'shared' %>  <%# Specify packs explicitly %>
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
    <%= javascript_pack_tag 'shared' %>
  </body>
</html>
```

**Important:** When you provide explicit pack names, `send_pack_early_hints` **ignores the queues** and only sends hints for the packs you specify.

### Selective Hints (Override Queue Discovery)

If you're using the append/prepend pattern but want to **exclude some packs** from early hints:

```erb
<%# View queues both 'application' and 'admin' via append_javascript_pack_tag %>
<% send_pack_early_hints 'application' %>  <%# Only hint for application, ignore admin %>
<!DOCTYPE html>
...
```

**Use case:** You have a large admin pack (2MB) that's only used by 5% of users. Instead of preloading it for everyone, only send early hints for the critical `application` pack.

**Trade-off:** Saves bandwidth for most users, but admin users won't get the early hints benefit.

### Per-Call Configuration Override

You can also override the global `include_css`/`include_js` settings per call:

```erb
<%# Only send hints for JavaScript, not CSS (overrides config) %>
<% send_pack_early_hints 'application', include_css: false, include_js: true %>
```

**When to use:** Rarely needed, but useful if you want different behavior for different packs.

## Requirements

- **Rails 5.2+** (for `request.send_early_hints` support)
- **Web server with HTTP/2 and early hints support:**
  - Puma 5+ ✅
  - nginx 1.13+ with ngx_http_v2_module ✅
  - Other HTTP/2-capable servers with early hints support
- **Browser support:** All modern browsers (Chrome 103+, Firefox 103+, Safari 16.4+, Edge 103+)

## Should I Enable This in Production?

**Yes, for most production apps!** Early hints provide:

- ✅ Faster page loads (browser downloads assets during server processing)
- ✅ Graceful degradation (disabled automatically if server/browser doesn't support it)
- ✅ Minimal overhead (tiny HTTP 103 response, ~1KB)
- ✅ No code changes needed (works with existing `append_*` pattern)

**Downsides:**

- Negligible bandwidth for HTTP 103 response
- Requires HTTP/2-capable infrastructure

**Default is `false`** to avoid surprises during upgrades, but we recommend enabling it in production once you've verified your infrastructure supports HTTP/2.

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

```text
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

```text
Request → HTTP 103 sent → Browser downloads JS (2s running in parallel!)
       → Rails renders (3s) → Browser gets HTML → JS already downloaded! → Total: 3s
```

**2 second improvement!** Browser downloads assets **during** server think time.

## Further Reading

- [Rails API: send_early_hints](https://api.rubyonrails.org/classes/ActionDispatch/Request.html#method-i-send_early_hints)
- [RFC 8297: HTTP Early Hints](https://datatracker.ietf.org/doc/html/rfc8297)
- [Eileen Codes: HTTP/2 Early Hints](https://eileencodes.com/posts/http2-early-hints/)
