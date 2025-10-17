# Feature Testing Guide

This guide shows how to manually verify that Shakapacker features are working correctly in your application.

## Table of Contents

- [HTTP 103 Early Hints](#http-103-early-hints)
- [Asset Compilation](#asset-compilation)
- [Code Splitting](#code-splitting)
- [Subresource Integrity (SRI)](#subresource-integrity-sri)
- [Source Maps](#source-maps)
- [Development Server](#development-server)

## HTTP 103 Early Hints

### Prerequisites

- Rails 5.2+
- HTTP/2-capable server (Puma 5+ recommended)
- Modern browser (Chrome/Edge/Firefox 103+, Safari 16.4+)

### Method 1: Browser DevTools (Recommended)

1. **Enable early hints in config:**

   ```yaml
   # config/shakapacker.yml
   production:
     early_hints:
       enabled: true
   ```

2. **Open Chrome DevTools** (F12 or Cmd+Option+I)

3. **Go to Network tab** and reload your page

4. **Look for the initial document request** (usually first row)

5. **Check the Status column** - you should see:
   - `103 Early Hints` (shown briefly before the final response)
   - Followed by `200 OK` for the final HTML

6. **Verify Link headers:**
   - Click on the document request
   - Go to the "Headers" tab
   - Scroll to "Response Headers" section
   - Look for `Link:` headers with `rel=preload` or `rel=prefetch`

**Expected output:**

```
Link: </packs/application-abc123.js>; rel=preload; as=script; crossorigin="anonymous"
Link: </packs/application-xyz789.css>; rel=preload; as=style; crossorigin="anonymous"
```

### Method 2: curl (Command Line)

**Test early hints with curl:**

```bash
# Using curl with verbose output
curl -v --http2 https://your-app.com 2>&1 | grep -A5 "< HTTP"

# Look for:
# < HTTP/2 103
# < link: </packs/...>; rel=preload
# < HTTP/2 200
```

**For local development (Puma):**

```bash
# Start Rails with Puma in production mode
RAILS_ENV=production bundle exec rails server

# In another terminal, test with curl
curl -v --http2 http://localhost:3000 2>&1 | grep -A10 "< HTTP"
```

**Expected output:**

```
< HTTP/2 103
< link: </packs/application-abc123.js>; rel=preload; as=script; crossorigin="anonymous"
< link: </packs/application-xyz789.css>; rel=preload; as=style; crossorigin="anonymous"
<
< HTTP/2 200
< content-type: text/html; charset=utf-8
```

### Method 3: Check HTML Source

Early hints don't appear in HTML source (they're sent as HTTP headers before HTML). However, you can verify the assets exist:

```html
<!-- View page source and look for these tags in <head> or before </body> -->
<script src="/packs/application-abc123.js"></script>
<link rel="stylesheet" href="/packs/application-xyz789.css" />
```

The asset filenames in early hints should match those in your HTML.

### Troubleshooting Early Hints

**Not seeing 103 status?**

1. **Check server supports HTTP/2 and early hints:**

   ```bash
   # Puma version (need 5+)
   bundle exec puma --version
   ```

2. **Verify config is enabled:**

   ```bash
   # In Rails console
   Shakapacker.config.early_hints
   # Should return: { enabled: true, css: "preload", js: "preload" }
   ```

3. **Check Rails log for debug messages:**

   ```bash
   tail -f log/production.log | grep -i "early hints"
   ```

4. **Verify your server uses HTTP/2:**
   ```bash
   curl -I --http2 https://your-app.com | grep -i "HTTP/2"
   ```

## Asset Compilation

### Verify Assets Compile Successfully

**Check manifest.json:**

```bash
# Development
cat public/packs/manifest.json | jq .

# Production (after precompile)
cat public/packs/manifest.json | jq '.entrypoints'
```

**Expected output:**

```json
{
  "entrypoints": {
    "application": {
      "assets": {
        "js": [
          "/packs/vendors~application-abc123.chunk.js",
          "/packs/application-xyz789.js"
        ],
        "css": ["/packs/application-abc123.chunk.css"]
      }
    }
  }
}
```

**Verify assets exist on disk:**

```bash
ls -lh public/packs/
# Should see .js, .css, .map files with hashed names
```

### Check HTML References

**View page source and verify pack tags:**

```html
<!-- Should see hashed filenames -->
<link rel="stylesheet" href="/packs/application-abc123.css" />
<script src="/packs/application-xyz789.js"></script>
```

## Code Splitting

### Verify Chunks Are Created

**Check manifest.json for chunks:**

```bash
cat public/packs/manifest.json | jq '.entrypoints.application.assets.js'
```

**Expected output (with code splitting):**

```json
[
  "/packs/vendors~application-abc123.chunk.js", // Vendor chunk
  "/packs/application-xyz789.js" // Main chunk
]
```

**View Network tab in DevTools:**

- Should see multiple `.chunk.js` files loading
- Chunks load in order (vendors first, then application code)

## Subresource Integrity (SRI)

### Verify Integrity Attributes

**Enable SRI in config:**

```yaml
# config/shakapacker.yml
production:
  integrity:
    enabled: true
```

**Check manifest.json for integrity hashes:**

```bash
cat public/packs/manifest.json | jq '.application.js'
```

**Expected output:**

```json
{
  "src": "/packs/application-abc123.js",
  "integrity": "sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC"
}
```

**Check HTML for integrity attribute:**

```html
<!-- View page source -->
<script
  src="/packs/application-abc123.js"
  integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC"
  crossorigin="anonymous"
></script>
```

### Verify SRI Works

**Break the integrity (for testing):**

1. Edit `public/packs/application-xyz789.js` (add a space)
2. Reload page
3. **Expected:** Browser console shows SRI error:
   ```
   Failed to find a valid digest in the 'integrity' attribute
   ```

## Source Maps

### Verify Source Maps Generate

**Check for .map files:**

```bash
ls -lh public/packs/*.map
# Should see .js.map and .css.map files
```

**Check HTML references source maps:**

```bash
curl http://localhost:3000/packs/application-xyz789.js | tail -5
```

**Expected output:**

```javascript
//# sourceMappingURL=application-xyz789.js.map
```

### Verify Source Maps Work in DevTools

1. **Open DevTools** → Sources tab
2. **Find your source files** under `webpack://` or `src/`
3. **Set a breakpoint** in your original source code
4. **Trigger the code** - debugger should stop at your source, not compiled output

## Development Server

### Verify Dev Server Running

**Check server status:**

```bash
# Start dev server
./bin/shakapacker-dev-server

# In another terminal, check it's running
curl http://localhost:3035
# Should return: "Shakapacker is running"
```

**Check Rails connects to dev server:**

```bash
# Start Rails
./bin/dev  # or rails server

# Check Rails log for:
[Shakapacker] Compiling...
[Shakapacker] Compiled all packs in /app/public/packs
```

**Verify hot reloading:**

1. Edit a JavaScript file in `app/javascript/`
2. Save the file
3. Browser should automatically reload (if HMR configured)
4. Or check terminal shows recompile message

### Troubleshooting Dev Server

**Connection refused?**

```bash
# Check dev_server.yml
cat config/shakapacker.yml | grep -A10 "dev_server"

# Verify settings:
# host: localhost
# port: 3035
# https: false
```

**Test connection manually:**

```bash
curl http://localhost:3035/packs/application.js
# Should return JavaScript code (not 404)
```

## Testing Checklist

Use this checklist to verify a complete Shakapacker setup:

- [ ] **Assets compile:** `bundle exec rails assets:precompile` succeeds
- [ ] **Manifest exists:** `public/packs/manifest.json` contains entrypoints
- [ ] **Assets load:** Page loads without 404s for pack files
- [ ] **Code splitting works:** Multiple chunks load in Network tab
- [ ] **Source maps work:** Can debug original source in DevTools
- [ ] **Dev server runs:** `./bin/shakapacker-dev-server` starts successfully
- [ ] **SRI enabled (if configured):** HTML contains `integrity` attributes
- [ ] **Early hints work (if configured):** DevTools shows 103 status

## Common Issues

### Assets Return 404

**Check manifest:**

```bash
cat public/packs/manifest.json | jq .
```

**Recompile:**

```bash
bundle exec rails assets:precompile
```

### Old Assets Cached

**Clear public/packs:**

```bash
rm -rf public/packs
bundle exec rails assets:precompile
```

### Dev Server Won't Start

**Check port not in use:**

```bash
lsof -i :3035
# Kill process if needed
kill -9 <PID>
```

**Check dev_server config:**

```bash
cat config/shakapacker.yml | grep -A10 dev_server
```

## Additional Resources

- [Configuration Guide](configuration.md)
- [Early Hints Guide](early_hints.md)
- [Subresource Integrity Guide](subresource_integrity.md)
- [Troubleshooting Guide](troubleshooting.md)
