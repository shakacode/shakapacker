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

## Testing & Verification

### How to Verify Early Hints Are Working

**1. Check Browser DevTools (Easiest Method)**

Open Chrome DevTools → Network tab:

1. Load your page in production (or staging with early hints enabled)
2. Look at the **Protocol** column (may need to right-click headers to enable it)
3. Find your asset files (JS/CSS from Shakapacker)
4. Check the **Initiator** column - should show `Early Hints` or `103`

**Example:**

```
Name                    Protocol  Initiator
application-abc123.js   h2        Early Hints
application-abc123.css  h2        Early Hints
```

**2. Check Response Headers (More Detail)**

Using `curl` in terminal:

```bash
# Use --http2 flag and look for HTTP/103 response
curl -I --http2 https://your-app.com/some-page

# You should see output like:
HTTP/2 103
link: </packs/application-k344a6d59eef8632c9d1.js>; rel=preload; as=script
link: </packs/application-k344a6d59eef8632c9d1.css>; rel=preload; as=style

HTTP/2 200
...
```

The `HTTP/2 103` response comes first, followed by the final `HTTP/2 200`.

**3. Check Rails Logs**

In development, you can add debugging to see what's being sent:

```ruby
# Temporarily add to lib/shakapacker/helper.rb after line 222
Rails.logger.info("🚀 Early Hints: #{headers.inspect}")
```

Look for log output like:

```
🚀 Early Hints: {"Link"=>["</packs/application.js>; rel=preload; as=script", ...]}
```

**4. Network Timing Analysis**

In Chrome DevTools → Network → Timing tab:

- **Without early hints**: "Waiting (TTFB)" is long, then "Content Download" starts
- **With early hints**: Assets show "Stalled" time reduced (started downloading earlier)

### Common Issues & Solutions

**Issue: No HTTP 103 responses visible**

Possible causes:

- ✅ **Check config**: `early_hints: enabled: true` in `config/shakapacker.yml`
- ✅ **Check server**: Puma 5+? Run `puma --version` to verify
- ✅ **Check HTTP/2**: Server must support HTTP/2 (HTTPS required)
- ✅ **Check placement**: `send_pack_early_hints` must be AFTER `yield` in layout
- ✅ **Check Rails version**: Need Rails 5.2+

**Issue: "Wrong" assets preloaded**

Debug what packs are queued:

```ruby
# Temporarily add before send_pack_early_hints in layout:
<% Rails.logger.info("JS Queue: #{@javascript_pack_tag_queue.inspect}") %>
<% Rails.logger.info("CSS Queue: #{@stylesheet_pack_tag_queue.inspect}") %>
<% send_pack_early_hints %>
```

Solution: Either fix your `append_*` calls or use explicit pack names.

**Issue: Works in production but not development**

This is **expected behavior**:

- Development has `early_hints: enabled: false` by default
- Minimal benefit in dev (fast local responses)
- To test in dev, temporarily set `enabled: true` in `config/shakapacker.yml`

**Issue: No performance improvement**

Early hints help most when:

- ✅ Server response time is slow (>500ms)
- ✅ Assets are large (>100KB)
- ✅ Network latency is high (mobile, slow connections)

If your server responds in <100ms with small assets, the benefit will be minimal.

### Production Verification Checklist

Before deploying to production:

- [ ] Verified HTTP/2 is enabled on server
- [ ] Puma 5+ or equivalent server with early hints support
- [ ] `early_hints: enabled: true` in production config
- [ ] `send_pack_early_hints` called AFTER `yield` in layout
- [ ] Tested in staging environment with production-like server
- [ ] Checked DevTools Network tab shows "Early Hints" initiator
- [ ] Verified correct assets are being preloaded (not too many/few)

## Troubleshooting

**Early hints not working?**

- Verify Rails 5.2+ and server supports HTTP/2 + early hints
- Check `early_hints: enabled: true` in config
- Use curl to check for HTTP 103 responses (see Testing section above)

**Wrong assets preloaded?**

- Add debug logging to see what's in queues (see Testing section)
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
