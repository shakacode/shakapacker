# Testing Early Hints in react-webpack-rails-tutorial

## The Problem We Fixed

The automatic early hints feature was fundamentally broken because it ran in `after_action`, which executes **after** view rendering completes and the response is ready. By that time, it's too late - the whole point of "early" hints is to send them while Rails is still working (processing or rendering) so the browser can download assets in parallel.

## Implementation Required

Early hints must be explicitly called. **Two patterns** (both work!):

### Pattern 1: In Layout (RECOMMENDED - Simpler)

Add to the **top** of your layout file:

```erb
<%# app/views/layouts/hello_world.html.erb %>
<% send_pack_early_hints 'hello-world-bundle' %>
<!DOCTYPE html>
<html>
  <head>
    <title>Hello World</title>
    <%= csrf_meta_tags %>
    <%= stylesheet_pack_tag 'hello-world-bundle' %>
  </head>
  <body>
    <%= yield %>  <%# Browser downloads assets while views render %>
    <%= javascript_pack_tag 'hello-world-bundle' %>
  </body>
</html>
```

**Why this works:**

- Controller finishes first (queries complete)
- Layout starts rendering, hits `send_pack_early_hints`
- HTTP 103 sent immediately
- Browser downloads assets **while Rails renders rest of layout/views**
- By the time HTML is done, assets are downloaded

**Parallelism:** Browser downloading ↔ Rails rendering views/partials

**When to use:** Most cases. Works well when view rendering takes time (complex partials, lots of helpers).

### Pattern 2: In Controller (For Heavy Queries)

Add to controller before expensive database work:

```ruby
class HelloWorldController < ApplicationController
  def index
    # Send hints BEFORE expensive work
    view_context.send_pack_early_hints('hello-world-bundle')

    # Browser downloads assets while these run
    @posts = Post.expensive_query      # 200ms
    @stats = Statistics.calculate      # 150ms
    # Total: 350ms of parallel download time!
  end
end
```

**Why use this:**

- HTTP 103 sent before controller work
- Browser downloads assets **while controller runs queries/API calls**
- When views start rendering, assets may already be downloaded

**Parallelism:** Browser downloading ↔ Controller queries/processing

**When to use:** When controller has significant work (>100ms of queries/processing). Maximizes benefit.

## How to Test

### 1. Choose Your Pattern

Pick Pattern 1 (layout) OR Pattern 2 (controller) from above. Pattern 1 is simpler for most cases.

### 2. Enable Debug Mode

Update `config/shakapacker.yml`:

```yaml
production:
  early_hints:
    enabled: true
    debug: true # Shows what hints are sent as HTML comments
```

### 3. Deploy to Control Plane

```bash
git add .
git commit -m "Add early hints to hello_world controller"
git push
```

### 4. Verify Early Hints Are Sent

#### Method 1: Check HTML Source (Easiest)

1. Visit your deployed app: https://rails-r1cbkt3n3tnvg.cpln.app/
2. View page source (Cmd+U or right-click → View Page Source)
3. Look for debug comments at the top of `<head>`:

```html
<!-- Shakapacker Early Hints Debug -->
<!-- Status: SENT -->
<!-- HTTP/2 Support: YES (https) -->
<!-- Packs: hello-world-bundle -->
<!-- Links Sent: -->
<!--   </packs/hello-world-bundle-abc123.js>; rel=preload; as=script; crossorigin="anonymous" -->
<!--   </packs/hello-world-bundle-xyz789.css>; rel=preload; as=style; crossorigin="anonymous" -->
<!-- -->
```

**If you see "Status: SENT"** - Early hints are working! Rails is sending them.

**If you see "Status: SKIPPED"** - Check the reason in the comments.

#### Method 2: curl (Shows Proxy Stripping)

```bash
curl -v --http2 https://rails-r1cbkt3n3tnvg.cpln.app/ 2>&1 | grep "< HTTP"
```

**Expected on Control Plane:**

```
< HTTP/2 200
```

**Why no 103?** Control Plane's reverse proxy strips HTTP/2 103 responses before they reach clients. This is common with proxies/CDNs. The debug HTML comments confirm Rails is sending them server-side.

#### Method 3: Browser DevTools (If Proxy Doesn't Strip)

1. Open Chrome DevTools (F12)
2. Go to Network tab
3. Reload page
4. Click the first document request
5. Look for `103 Early Hints` status (if proxy supports it)

**Note:** On Control Plane, you won't see 103 in DevTools because the proxy strips it. Use HTML comments to verify.

## What Packs to Hint?

Check your layout to see what packs are loaded:

```erb
<%# app/views/layouts/hello_world.html.erb %>
<%= javascript_pack_tag 'hello-world-bundle' %>
```

Pass those pack names (without extensions) to `send_pack_early_hints`:

```ruby
view_context.send_pack_early_hints('hello-world-bundle')
```

If you have multiple packs:

```ruby
view_context.send_pack_early_hints('hello-world-bundle', 'vendor-bundle')
```

## Common Issues

### "Status: SKIPPED - No pack names provided"

You forgot to pass pack names:

```ruby
# Wrong:
view_context.send_pack_early_hints()

# Right:
view_context.send_pack_early_hints('hello-world-bundle')
```

### "Status: SKIPPED - early_hints.enabled is false"

Enable early hints in `config/shakapacker.yml`:

```yaml
production:
  early_hints:
    enabled: true
    debug: true
```

### Debug comments not showing

Make sure you're calling from the controller, not a view/layout:

```ruby
# app/controllers/hello_world_controller.rb
class HelloWorldController < ApplicationController
  def index
    view_context.send_pack_early_hints('hello-world-bundle')
  end
end
```

## Performance Impact

Early hints provide the most benefit when:

1. **You have expensive controller work** (database queries, API calls)
2. **Assets are large** (hundreds of KB of JS/CSS)
3. **Network latency is high** (mobile users, distant servers)

For a simple "Hello World" app with fast responses, early hints won't show measurable improvement. The real benefit appears in production apps with:

- Complex database queries
- External API calls
- Heavy computation
- Large JavaScript bundles

## Summary

✅ **DO**: Call `send_pack_early_hints` in controller actions before expensive work

❌ **DON'T**: Call it in views/layouts (too late)

✅ **DO**: Use debug mode to verify hints are sent

❌ **DON'T**: Expect to see HTTP/2 103 on Control Plane (proxy strips it)

✅ **DO**: Pass explicit pack names

❌ **DON'T**: Call without pack names (will be skipped)
