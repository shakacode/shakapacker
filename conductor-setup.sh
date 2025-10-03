#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Setting up Shakapacker workspace..."

# Set up Ruby version if asdf is available
if command -v asdf &> /dev/null; then
    echo "📝 Using asdf Ruby version management..."
    # Ensure we have the right Ruby version file
    echo "ruby 3.3.4" > .tool-versions
    # Use asdf exec to run commands with the right Ruby version
    BUNDLE_CMD="asdf exec bundle"
else
    BUNDLE_CMD="bundle"
fi

# Check for required tools
if ! $BUNDLE_CMD --version &> /dev/null; then
    echo "❌ Error: Ruby bundler is not installed"
    echo "Please install bundler first: gem install bundler"
    exit 1
fi

if ! command -v yarn &> /dev/null; then
    echo "❌ Error: Yarn is not installed"
    echo "Please install yarn first"
    exit 1
fi

# Install Ruby dependencies
echo "📦 Installing Ruby dependencies..."
$BUNDLE_CMD install

# Install JavaScript dependencies
echo "📦 Installing JavaScript dependencies..."
yarn install

# Set up Husky git hooks
echo "🪝 Setting up Husky git hooks..."
npx husky
if [ ! -f .husky/pre-commit ]; then
    echo "Creating pre-commit hook..."
    cat > .husky/pre-commit << 'EOF'
#!/usr/bin/env sh
npx lint-staged
EOF
    chmod +x .husky/pre-commit
fi

# Copy environment files if they exist in root
if [ -n "${CONDUCTOR_ROOT_PATH:-}" ]; then
    if [ -f "$CONDUCTOR_ROOT_PATH/.env" ]; then
        echo "📋 Copying .env file from root..."
        cp "$CONDUCTOR_ROOT_PATH/.env" .env
    fi
    
    if [ -f "$CONDUCTOR_ROOT_PATH/.env.local" ]; then
        echo "📋 Copying .env.local file from root..."
        cp "$CONDUCTOR_ROOT_PATH/.env.local" .env.local
    fi
fi

echo "✅ Workspace setup complete!"
echo ""
echo "Available commands:"
echo "  - Run tests: bundle exec rspec"
echo "  - Run specific test suites: bundle exec rake run_spec:gem"
echo "  - Run JavaScript tests: yarn test"
echo "  - Lint JavaScript: yarn lint"
echo "  - Lint Ruby: bundle exec rubocop"