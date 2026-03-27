# Shakapacker Competitive Landscape

Reference for understanding what competitors offer so we can match or exceed them in documentation quality.

## Shakapacker Competitors

### Vite Ruby (vite-ruby.netlify.app)

The primary alternative to Shakapacker for JS bundling in Rails.

Doc site structure:

- Introduction (motivation, comparison)
- Getting Started (multi-framework install)
- Development, Deployment, Advanced, Plugins
- Rails Integration (tag helpers, asset handling)
- Configuration Reference (every option in a table)
- Troubleshooting
- Overview (internals for curious devs)

Key differentiators:

- Clear framework-specific install paths
- Recommended plugins page
- Link to example app on Heroku

### jsbundling-rails (github.com/rails/jsbundling-rails)

- Very short README
- Relies on official Rails guides for context
- No dedicated docs site
- Simple by design (thin wrapper)

### Webpacker (legacy, github.com/rails/webpacker)

- Was the Rails default
- README plus docs/ directory
- Now deprecated; Shakapacker is the successor

## Unique Strengths to Highlight in Docs

- Official successor to rails/webpacker
- Drop-in replacement for webpacker
- Active maintenance by ShakaCode
- Webpack 5 with full configuration access
- Rspack compatibility for faster builds

## Documentation Improvement Targets

Based on competitive analysis:

1. **Configuration Reference page** (Vite Ruby does this well with a table of every option)
2. **Troubleshooting page** derived from top GitHub Issues
3. **Comparison page** that honestly compares Shakapacker vs Vite Ruby vs jsbundling-rails
4. **Upgrade guides** for each major version with before/after code
5. **LLMs.txt** for AI agent consumption
