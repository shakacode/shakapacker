# Shakapacker Documentation Templates

Project-specific template details for Shakapacker documentation. These supplement
the generic templates in the shared claude-code-commands-skills-agents repo.

## README Hello World

Use a webpack/rspack configuration example rather than a React component example:

```javascript
// config/webpack/webpack.config.js
const { generateWebpackConfig } = require("shakapacker")
module.exports = generateWebpackConfig()
```

```erb
<%# In your Rails view %>
<%= javascript_pack_tag 'application' %>
<%= stylesheet_pack_tag 'application' %>
```

## Requirements Section

When documenting requirements, use:

```markdown
## Requirements

- Ruby >= 3.0
- Rails >= 6.1
- Node >= 18
- Shakapacker >= 8.0 (supports both webpack and rspack)
```

## Quick Start Steps

Shakapacker-specific installation flow:

```bash
# 1. Add the gem
bundle add shakapacker --strict

# 2. Run the installer
rails shakapacker:install

# 3. Start the dev server
bin/shakapacker-dev-server
```

## Configuration Reference

Shakapacker configuration lives in `config/shakapacker.yml`. When documenting
config options, include both webpack and rspack variants where they differ.
