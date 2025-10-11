# Precompile Hook

The `precompile_hook` configuration option allows you to run a custom command before asset compilation. This is useful for:

- Dynamically generating entry points (e.g., from database records)
- Running preparatory tasks before bundling
- Integrating with tools like React on Rails that need to generate packs

## When to Use

The precompile hook is especially useful when you need to run commands like:

- `bin/rails react_on_rails:generate_packs` - Generate dynamic entry points
- `bin/rails react_on_rails:locale` - Generate locale files
- Any custom script that prepares files before asset compilation

**Important:** The hook runs in **both development and production**:

- **Development**: Runs before `bin/shakapacker --watch` or dev server starts
- **Production**: Runs before `rails assets:precompile`

## Configuration

Add the `precompile_hook` option to your `config/shakapacker.yml`:

```yaml
# For all environments
default: &default
  precompile_hook: "bin/shakapacker-precompile-hook"

# Or environment-specific
development:
  <<: *default
  precompile_hook: "bin/dev-setup"

production:
  <<: *default
  precompile_hook: "bin/rails react_on_rails:generate_packs"
```

## Creating a Precompile Hook Script

### Simple Shell Script

```bash
#!/usr/bin/env bash
# bin/shakapacker-precompile-hook

echo "Preparing assets..."
bin/rails react_on_rails:generate_packs
bin/rails react_on_rails:locale
echo "Assets prepared successfully"
```

### Ruby Script with Database Access

```ruby
#!/usr/bin/env ruby
# bin/shakapacker-precompile-hook

require_relative "../config/environment"

puts "Generating dynamic entry points..."

# Generate entry points from database
Theme.find_each do |theme|
  entry_point = Rails.root.join("app/javascript/packs/theme_#{theme.id}.js")
  File.write(entry_point, "import '../themes/#{theme.identifier}';")
  puts "  Created #{entry_point}"
end

puts "Entry points generated successfully"
exit 0
```

Make the script executable:

```bash
chmod +x bin/shakapacker-precompile-hook
```

## How It Works

### Execution Flow

1. **Triggered** when asset compilation starts
2. **Hook runs** in your project root directory
3. **Environment variables** are passed through (including `NODE_ENV`, `RAILS_ENV`, `SHAKAPACKER_ASSET_HOST`)
4. **On success** (exit code 0): Compilation proceeds
5. **On failure** (non-zero exit code): Compilation stops with error

**Migration Note:** If you're migrating from custom `assets:precompile` enhancements (e.g., in `lib/tasks/assets.rake`), ensure you don't run the same commands twice. React on Rails versions before 16.1.1 automatically prepend `react_on_rails:generate_packs` to `assets:precompile`. Versions 16.1.1+ detect `precompile_hook` and skip automatic task enhancement to avoid duplicate execution. For custom Rake task enhancements, remove manual invocations when adding `precompile_hook`.

### Logging

The hook's stdout and stderr are logged:

```
Running precompile hook: bin/shakapacker-precompile-hook
Preparing assets...
Entry points generated successfully
Precompile hook completed successfully
Compiling...
```

## React on Rails Integration

For React on Rails projects, the hook replaces manual steps in your workflow:

### Before (Manual)

```bash
# Development
bin/rails react_on_rails:generate_packs
bin/rails react_on_rails:locale
bin/shakapacker-dev-server

# Production
bin/rails react_on_rails:generate_packs
bin/rails react_on_rails:locale
RAILS_ENV=production bin/rails assets:precompile
```

### After (Automatic)

```yaml
# config/shakapacker.yml
default: &default
  precompile_hook: "bin/react-on-rails-hook"
```

```bash
#!/usr/bin/env bash
# bin/react-on-rails-hook
bin/rails react_on_rails:generate_packs
bin/rails react_on_rails:locale
```

Now simply run:

```bash
# Development
bin/shakapacker-dev-server

# Production
RAILS_ENV=production bin/rails assets:precompile
```

## Security

For security reasons, the precompile hook is validated to ensure:

### 1. Project Root Restriction

The hook **must** reference a script within your project root:

```yaml
# ✅ Valid - within project
precompile_hook: 'bin/shakapacker-precompile-hook'
precompile_hook: 'script/prepare-assets'
precompile_hook: 'bin/hook --arg1 --arg2'

# ❌ Invalid - outside project
precompile_hook: '/usr/bin/malicious-script'
precompile_hook: '../../../etc/passwd'
```

### 2. Symlink Resolution

Symlinks are resolved to their real paths before validation:

```bash
# If bin/hook is a symlink to /usr/bin/evil
# The validation will detect and reject it
```

### 3. Path Traversal Protection

Path traversal attempts are blocked:

```yaml
# ❌ These will be rejected
precompile_hook: 'bin/../../etc/passwd'
precompile_hook: '../outside-project/script'
```

### 4. Proper Path Boundary Checking

Partial path matches are prevented:

```
# /project won't match /project-evil
# Uses File::SEPARATOR for proper validation
```

## Error Handling

### Hook Failure

If the hook fails, you'll see a detailed error:

```
PRECOMPILE HOOK FAILED:
EXIT STATUS: 1
COMMAND: bin/shakapacker-precompile-hook
OUTPUTS:
Error: Theme not found

To fix this:
  1. Check that the hook script exists and is executable
  2. Test the hook command manually: bin/shakapacker-precompile-hook
  3. Review the error output above for details
  4. You can disable the hook temporarily by commenting out 'precompile_hook' in shakapacker.yml
```

### Missing Executable

If the script doesn't exist, you'll see a warning:

```
⚠️  Warning: precompile_hook executable not found: /path/to/project/bin/hook
   The hook command is configured but the script does not exist within the project root.
   Please ensure the script exists or remove 'precompile_hook' from your shakapacker.yml configuration.
```

## Troubleshooting

### Test the Hook Manually

Run the hook directly to see what happens:

```bash
bin/shakapacker-precompile-hook
echo $?  # Should output 0 for success
```

### Check Permissions

Ensure the script is executable:

```bash
ls -la bin/shakapacker-precompile-hook
# Should show: -rwxr-xr-x (executable)

# If not executable:
chmod +x bin/shakapacker-precompile-hook
```

### Debug with Verbose Output

Add debug output to your hook:

```bash
#!/usr/bin/env bash
set -x  # Enable verbose mode
echo "Current directory: $(pwd)"
echo "Environment: $RAILS_ENV"
# Your commands here
```

### Temporarily Disable

To disable the hook for testing:

```yaml
# config/shakapacker.yml
default:
  # precompile_hook: 'bin/shakapacker-precompile-hook'
```

### Common Issues

**Issue:** Hook fails in production but works in development - Verify all dependencies are available (database, commands, gems)

**Issue:** Generated files not found - Check `source_path` and `source_entry_path` in `shakapacker.yml`

**Issue:** Permission denied - Run `chmod +x bin/shakapacker-precompile-hook`

## Advanced Usage

### Conditional Execution

```bash
#!/usr/bin/env bash
# bin/shakapacker-precompile-hook

if [ "$RAILS_ENV" = "production" ]; then
  echo "Running production-specific setup..."
  bin/rails react_on_rails:generate_packs
else
  echo "Running development setup..."
  # Lighter-weight setup for development
fi
```

### Hook with Arguments

```yaml
precompile_hook: "bin/prepare-assets --verbose --cache-bust"
```

```bash
#!/usr/bin/env bash
# bin/prepare-assets

VERBOSE=false
CACHE_BUST=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose) VERBOSE=true ;;
    --cache-bust) CACHE_BUST=true ;;
  esac
  shift
done

if [ "$VERBOSE" = true ]; then
  echo "Preparing assets..."
fi
```

### Handling Spaces in Paths

Use quotes for paths with spaces:

```yaml
precompile_hook: "'bin/my hook script' --arg1"
```

The hook system uses `Shellwords` to properly parse quoted arguments.

## See Also

- [Deployment Guide](deployment.md) - Production deployment considerations
- [React on Rails Integration](https://github.com/shakacode/react_on_rails) - Main use case documentation
- [Configuration](../README.md#configuration-and-code) - General shakapacker configuration
