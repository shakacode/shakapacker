# HTTP 103 Early Hints Guide

This guide shows you how to use HTTP 103 Early Hints with Shakapacker for faster page loads.

## What are Early Hints?

HTTP 103 Early Hints allows browsers to start downloading critical assets (JS, CSS) **while** Rails is still rendering your views. This may significantly improve page load performance or cause an equally significant regression, depending on the page's content. For example, preloading JavaScript may hurt your LCP (Largest Contentful Paint) metric unless you also preload the largest image. **Careful experimentation and performance measurement is advised.**

### Performance Considerations

⚠️ **Important**: Preloading assets without measuring performance can hurt key metrics:

- **LCP Impact**: Preloading JS/CSS competes for bandwidth with images, potentially delaying LCP
- **Not Always Faster**: Pages with large hero images may perform worse with JS/CSS preloading
- **SSR Pages**: Server-rendered pages may not benefit as much from preloading
- **Recommendation**: Test with and without early hints, measure real-world performance metrics

## Quick Start - Zero Configuration!

Early hints work automatically once enabled - **no changes to your layouts or views needed**:

### 1. Enable in Configuration

```yaml
# config/shakapacker.yml
production:
  early_hints:
    enabled: true # default: false - must be explicitly enabled
    include_css: true # default: true when enabled - preload CSS chunks
    include_js: true # default: true when enabled - preload JS chunks
```

**That's it!** Early hints will be sent automatically for all HTML responses.

**Configuration options explained:**

- **`enabled`**: Master switch. Set to `true` in production. Default: `false`
- **`include_css`**: Send early hints for CSS files. Default: `true`
  - Set to `false` to skip CSS preloading (save bandwidth)
  - Only matters if your packs actually include CSS files
- **`include_js`**: Send early hints for JavaScript files. Default: `true`
  - Set to `false` to skip JS preloading (rare use case)

**Common configurations:**

```yaml
# Most common: Enable everything (recommended)
production:
  early_hints:
    enabled: true
    include_css: true
    include_js: true

# Skip CSS preloading (save bandwidth on large CSS files)
production:
  early_hints:
    enabled: true
    include_css: false  # Don't preload CSS
    include_js: true    # Only preload JS

# Skip JS preloading (rare - only preload CSS)
production:
  early_hints:
    enabled: true
    include_css: true   # Only preload CSS
    include_js: false   # Don't preload JS

# Disabled (default - no early hints sent)
production:
  early_hints:
    enabled: false
```

### 2. (Optional) Opt-Out for Specific Controllers

If you need to disable early hints for specific actions (e.g., JSON APIs, redirects):

```ruby
class ApiController < ApplicationController
  skip_send_pack_early_hints
end

class PostsController < ApplicationController
  skip_send_pack_early_hints only: [:api_endpoint, :json_action]
end
```

## How It Works

Shakapacker automatically sends early hints after your views render, using Rails' built-in lifecycle hooks:

```text
1. Request arrives
2. Controller action runs  → Database queries, business logic
3. Views render           → append_javascript_pack_tag('admin')  [queues populate]
4. Layout renders         → javascript_pack_tag, stylesheet_pack_tag, etc.
5. after_action hook      → Automatic send_pack_early_hints()    [reads queues!]
6. HTTP 103 sent          → Browser starts downloading assets
7. HTTP 200 sent          → Full HTML response sent to browser
```

**Important timing note**: With automatic early hints, the HTTP 103 response is sent AFTER rendering completes. This means:

- ✅ **Benefits**: Browser starts downloading JS/CSS before parsing HTML, parallel to network transmission
- ❌ **Limitations**: Does NOT help during database queries or view rendering time
- 💡 **Best for**: Pages where asset download time is the bottleneck, not server processing time

By the time the `after_action` hook runs, your views and layout have **already rendered**, so all pack queues are populated! The automatic behavior discovers all packs without any manual intervention.

## Example: Multi-Pack App

Your existing view code works automatically:

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

That's it! With `enabled: true`, early hints are automatically sent for **both** 'application' and 'admin' packs.

## Advanced: Manual Control (Rarely Needed)

**Most apps don't need manual control** - the automatic behavior works great. But if you need fine-grained control, you can manually call `send_pack_early_hints` in your layout.

### Manual Invocation in Layout

You can still call `send_pack_early_hints` manually in your layout. When you do, it overrides the automatic behavior for that request:

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <body>
    <%= yield %>
    <%= javascript_pack_tag 'application' %>
  </body>
</html>
<% send_pack_early_hints %>  <%# Manual call - disables automatic behavior %>
```

**Important:** Manual calls must be placed **after** `yield` so pack queues are populated.

**Why at the end?** Even though it appears at the end of the ERB template, `request.send_early_hints()` sends HTTP 103 **immediately** when called - before Rails finishes rendering the HTML. By the time HTTP 200 (with the HTML) is sent, the browser has already started downloading assets thanks to the HTTP 103 sent earlier.

### Explicit Pack Names (Bypass Queue Discovery)

If you know your pack names upfront, you can specify them explicitly:

```erb
<% send_pack_early_hints 'application', 'shared' %>  <%# Explicit names work anywhere! %>
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

### Selective Hints (Exclude Some Packs)

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
