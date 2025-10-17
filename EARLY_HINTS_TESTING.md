# Testing Early Hints in react-webpack-rails-tutorial

## The Problem We Fixed

The automatic early hints feature was fundamentally broken because it ran in `after_action`, which executes **after** view rendering completes. By that time, it's too late - the whole point of "early" hints is to send them **before** expensive work so assets download in parallel.

## Implementation Required

Early hints must be explicitly called in controller actions **before** expensive work:

```ruby
class HelloWorldController < ApplicationController
  def index
    # Send early hints FIRST - before any expensive work
    view_context.send_pack_early_hints('hello-world-bundle')

    # Now do work - assets download while Rails works
    # (In this simple app, there's no expensive work, but in production
    # this would be database queries, API calls, etc.)
  end
end
```

## How to Test

### 1. Update the Controller

Add early hints call to `app/controllers/hello_world_controller.rb`:

```ruby
class HelloWorldController < ApplicationController
  def index
    # Send early hints for the packs this page uses
    view_context.send_pack_early_hints('hello-world-bundle')
  end
end
```

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
