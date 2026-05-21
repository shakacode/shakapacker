#!/bin/zsh
set -euo pipefail

echo "🔧 Setting up Shakapacker workspace..."

# Engine requirements (kept in sync with package.json "engines" and lib/install/templates).
# @rspack/core v2 (Shakapacker v10+) requires Node ^20.19.0 || >=22.12.0.
SCRIPT_DIR="${0:A:h}"
MIN_RUBY_VERSION="2.7.0"
DEFAULT_RUBY_VERSION="3.3.4"
DEFAULT_NODE_VERSION="22.20.0"
source "$SCRIPT_DIR/bin/lib/node-version-check.sh"

# Set or update a `<tool> <version>` line in .tool-versions, preserving other entries.
upsert_tool_versions_line() {
    local tool="$1"
    local version="$2"
    local file=".tool-versions"
    if [[ ! -f "$file" ]]; then
        echo "$tool $version" > "$file"
        return
    fi
    if grep -qE "^${tool}[[:space:]]" "$file"; then
        local tmpfile="$file.tmp"
        awk -v tool="$tool" -v ver="$version" '
            $1 == tool { print tool " " ver; next }
            { print }
        ' "$file" > "$tmpfile" || { rm -f "$tmpfile"; return 1; }
        mv "$tmpfile" "$file" || { rm -f "$tmpfile"; return 1; }
    else
        # Ensure the file ends with a newline before appending, so the new entry doesn't
        # concatenate onto the last line of a hand-edited file missing its trailing \n.
        if [[ -s "$file" ]] && [[ "$(tail -c1 "$file"; echo x)" != $'\nx' ]]; then
            printf '\n' >> "$file"
        fi
        echo "$tool $version" >> "$file"
    fi
}

# Detect and initialize version manager
# Supports: mise, asdf, or direct PATH (rbenv/nvm/nodenv already in PATH)
VERSION_MANAGER="none"

echo "📋 Detecting version manager..."

if command -v mise &> /dev/null; then
    VERSION_MANAGER="mise"
    echo "✅ Found mise"
    # Trust mise config for current directory only
    mise trust 2>/dev/null || true
elif [[ -f ~/.asdf/asdf.sh ]]; then
    VERSION_MANAGER="asdf"
    source ~/.asdf/asdf.sh
    echo "✅ Found asdf (from ~/.asdf/asdf.sh)"
elif command -v asdf &> /dev/null; then
    VERSION_MANAGER="asdf"
    # For homebrew-installed asdf
    if [[ -f /opt/homebrew/opt/asdf/libexec/asdf.sh ]]; then
        source /opt/homebrew/opt/asdf/libexec/asdf.sh
    fi
    echo "✅ Found asdf"
else
    echo "ℹ️  No version manager detected, using system PATH"
    echo "   (Assuming rbenv/nvm/nodenv or system tools are already configured)"
fi

# Sync .tool-versions with project version files (asdf/mise only; skip when .mise.toml is authoritative)
if [[ "$VERSION_MANAGER" != "none" ]] && [[ ! -f .mise.toml ]]; then
    # Read any existing .tool-versions pins up front so we can prefer a supported value there
    # over the hard-coded default when .ruby-version / .node-version aren't present.
    existing_node=""
    existing_ruby=""
    if [[ -f .tool-versions ]]; then
        existing_node=$(awk '$1 == "nodejs" { print $2; exit }' .tool-versions)
        existing_ruby=$(awk '$1 == "ruby" { print $2; exit }' .tool-versions)
    fi

    if [[ -f .ruby-version ]]; then
        RUBY_VER=$(cat .ruby-version | tr -d '[:space:]')
    elif [[ -n "$existing_ruby" ]] && version_ge "$existing_ruby" "$MIN_RUBY_VERSION"; then
        RUBY_VER="$existing_ruby"
    else
        RUBY_VER="$DEFAULT_RUBY_VERSION"
    fi

    # Track the source so the unsupported-Node error message points at the right file to edit.
    if [[ -f .node-version ]]; then
        NODE_VER=$(cat .node-version | tr -d '[:space:]')
        # Strip leading `v` (valid nvm/nodenv format) so mise/asdf accept the value in .tool-versions
        # and the idempotency check below compares against the unprefixed value awk reads back.
        NODE_VER="${NODE_VER#v}"
        NODE_VER_SOURCE=".node-version"
    elif [[ -n "$existing_node" ]] && node_version_supported "$existing_node"; then
        NODE_VER="$existing_node"
        NODE_VER_SOURCE=".tool-versions"
    else
        NODE_VER="$DEFAULT_NODE_VERSION"
        NODE_VER_SOURCE="default"
    fi

    # Fail fast if the resolved Node version is unsupported, before mise installs the wrong version.
    if ! node_version_supported "$NODE_VER"; then
        echo "❌ Error: Node version $NODE_VER (from $NODE_VER_SOURCE) is unsupported." >&2
        echo "   Shakapacker requires Node ^20.19.0 || >=22.12.0 (matches package.json engines)." >&2
        echo "   Fix: update $NODE_VER_SOURCE to a supported version (e.g. $DEFAULT_NODE_VERSION), then rerun setup." >&2
        exit 1
    fi

    if [[ ! -f .tool-versions ]]; then
        echo "📝 Creating .tool-versions from project version files..."
        upsert_tool_versions_line "ruby" "$RUBY_VER"
        upsert_tool_versions_line "nodejs" "$NODE_VER"
        echo "   Using Ruby $RUBY_VER, Node $NODE_VER"
    elif [[ "$existing_node" != "$NODE_VER" ]] || [[ "$existing_ruby" != "$RUBY_VER" ]]; then
        echo "📝 Updating .tool-versions to match resolved versions..."
        [[ -z "$existing_node" ]] && \
            echo "   nodejs: (new) $NODE_VER"
        [[ -n "$existing_node" ]] && [[ "$existing_node" != "$NODE_VER" ]] && \
            echo "   nodejs: $existing_node → $NODE_VER"
        [[ -z "$existing_ruby" ]] && \
            echo "   ruby:   (new) $RUBY_VER"
        [[ -n "$existing_ruby" ]] && [[ "$existing_ruby" != "$RUBY_VER" ]] && \
            echo "   ruby:   $existing_ruby → $RUBY_VER"
        upsert_tool_versions_line "ruby" "$RUBY_VER"
        upsert_tool_versions_line "nodejs" "$NODE_VER"
        echo "   Using Ruby $RUBY_VER, Node $NODE_VER"
    else
        echo "✅ .tool-versions already in sync (Ruby $RUBY_VER, Node $NODE_VER)"
    fi
fi

# Install tools via mise (after .tool-versions exists)
if [[ "$VERSION_MANAGER" == "mise" ]]; then
    echo "📦 Installing tools via mise..."
    mise install
fi

# Helper function to run commands with the detected version manager
run_cmd() {
    if [[ "$VERSION_MANAGER" == "mise" ]] && [[ -x "bin/conductor-exec" ]]; then
        bin/conductor-exec "$@"
    else
        "$@"
    fi
}

# Check required tools
echo "📋 Checking required tools..."
run_cmd ruby --version >/dev/null 2>&1 || { echo "❌ Error: Ruby is not installed or not in PATH." >&2; exit 1; }
run_cmd node --version >/dev/null 2>&1 || { echo "❌ Error: Node.js is not installed or not in PATH." >&2; exit 1; }

# Check Ruby version
# Extract MAJOR.MINOR.PATCH; ignores any distro patch suffix (e.g., "+custom") so comparison is clean.
RUBY_RAW=$(run_cmd ruby -v 2>&1 || true)
RUBY_VERSION=$(echo "$RUBY_RAW" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
if [[ -z "$RUBY_VERSION" ]]; then
    echo "❌ Error: Could not parse Ruby version from \`ruby -v\`. Got: $RUBY_RAW" >&2
    exit 1
fi
if ! version_ge "$RUBY_VERSION" "$MIN_RUBY_VERSION"; then
    echo "❌ Error: Ruby version $RUBY_VERSION is too old. Shakapacker requires Ruby >= $MIN_RUBY_VERSION" >&2
    echo "   Please upgrade Ruby using your version manager or system package manager." >&2
    exit 1
fi
echo "✅ Ruby version: $RUBY_VERSION"

# Check Node version against ^20.19.0 || >=22.12.0 (rspack v2 engine constraint).
# Extract MAJOR.MINOR.PATCH; ignores any distro patch suffix (e.g., "v22.20.0+custom") so comparison is clean.
NODE_RAW=$(run_cmd node -v 2>&1 || true)
NODE_VERSION=$(echo "$NODE_RAW" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
if [[ -z "$NODE_VERSION" ]]; then
    echo "❌ Error: Could not parse Node.js version from \`node -v\`. Got: $NODE_RAW" >&2
    exit 1
fi
if ! node_version_supported "$NODE_VERSION"; then
    echo "❌ Error: Node.js version v$NODE_VERSION is unsupported. Shakapacker requires Node.js ^20.19.0 || >=22.12.0" >&2
    if [[ "$VERSION_MANAGER" == "mise" ]] && [[ -f .mise.toml ]]; then
        echo "   Hint: .mise.toml is the authoritative mise config for this workspace." >&2
        echo "   Update the Node version in .mise.toml, then run \`mise install\` and rerun setup." >&2
    elif [[ "$VERSION_MANAGER" == "mise" ]] && [[ -f .tool-versions ]]; then
        echo "   Hint: .tool-versions pins nodejs $(awk '$1 == "nodejs" { print $2; exit }' .tool-versions || echo '?')." >&2
        echo "   Update .node-version and rerun setup, or run \`mise install\` after fixing .tool-versions." >&2
    else
        echo "   Please upgrade Node.js using your version manager or system package manager." >&2
    fi
    exit 1
fi
echo "✅ Node.js version: v$NODE_VERSION"

# Copy any environment files from root if they exist
if [ -n "${CONDUCTOR_ROOT_PATH:-}" ]; then
    if [ -f "$CONDUCTOR_ROOT_PATH/.env" ]; then
        echo "📝 Copying .env file..."
        cp "$CONDUCTOR_ROOT_PATH/.env" .env
    fi

    if [ -f "$CONDUCTOR_ROOT_PATH/.env.local" ]; then
        echo "📝 Copying .env.local file..."
        cp "$CONDUCTOR_ROOT_PATH/.env.local" .env.local
    fi
fi

# Install Ruby dependencies
echo "💎 Installing Ruby dependencies..."
run_cmd bundle install

# Install JavaScript dependencies
echo "📦 Installing JavaScript dependencies..."
run_cmd yarn install --frozen-lockfile

# Set up Husky git hooks
echo "🪝 Setting up Husky git hooks..."
run_cmd npx husky
if [ ! -f .husky/pre-commit ]; then
    echo "Creating pre-commit hook..."
    cat > .husky/pre-commit << 'EOF'
#!/usr/bin/env sh
npx lint-staged
EOF
    chmod +x .husky/pre-commit
fi

# Verify linting tools are available
echo "✅ Verifying linting tools..."
run_cmd bundle exec rubocop --version

echo "✨ Workspace setup complete!"
echo ""
echo "📚 Key commands:"
echo "  • bundle exec rspec - Run Ruby tests"
echo "  • bundle exec rake run_spec:gem - Run gem-specific tests"
echo "  • yarn test - Run JavaScript tests"
echo "  • yarn lint - Run JavaScript linting"
echo "  • bundle exec rubocop - Run Ruby linting (required before commits)"
echo ""
if [[ "$VERSION_MANAGER" == "mise" ]]; then
    echo "💡 Tip: Use 'bin/conductor-exec <command>' if tool versions aren't detected correctly."
fi
echo "⚠️ Remember: Always run 'bundle exec rubocop' before committing!"
