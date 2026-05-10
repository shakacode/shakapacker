#!/usr/bin/env bash
# Publish core shakapacker first, then the supplemental packages.
#
# Sequencing is load-bearing: shakapacker-webpack and shakapacker-rspack both
# declare "shakapacker": "^X.Y.Z" as a required peer dep. Publishing a
# supplemental before core leaves installers with an unresolvable peer dep
# until core is published.
#
# Usage:
#   ./scripts/publish-packages.sh                      # publish to default dist-tag (latest)
#   ./scripts/publish-packages.sh --dry-run            # preview without publishing
#   ./scripts/publish-packages.sh --tag next           # publish under a non-default dist-tag
#   ./scripts/publish-packages.sh --tag=beta --dry-run # flags can appear in any order
#
# Pre-release versions (e.g. 10.1.0-beta.1) MUST be published with --tag (next,
# beta, rc, etc.) so they don't auto-promote to `latest` and become the default
# `npm install shakapacker` resolution.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=()
TAG=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=(--dry-run)
      shift
      ;;
    --tag=*)
      tag_value="${1#--tag=}"
      if [[ -z "$tag_value" ]]; then
        echo "Error: --tag requires a value (e.g., --tag next, --tag beta)" >&2
        exit 1
      fi
      TAG=(--tag "$tag_value")
      shift
      ;;
    --tag)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --tag requires a value (e.g., --tag next, --tag beta)" >&2
        exit 1
      fi
      TAG=(--tag "$2")
      shift 2
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      echo "Usage: $0 [--dry-run] [--tag <name>]" >&2
      exit 1
      ;;
  esac
done

CORE_VERSION="$(node -p "require('./package.json').version")"
WEBPACK_VERSION="$(node -p "require('./packages/shakapacker-webpack/package.json').version")"
RSPACK_VERSION="$(node -p "require('./packages/shakapacker-rspack/package.json').version")"

if [[ "$CORE_VERSION" != "$WEBPACK_VERSION" || "$WEBPACK_VERSION" != "$RSPACK_VERSION" ]]; then
  echo "Version mismatch — all three packages must share the same version (lockstep):" >&2
  echo "  shakapacker            = $CORE_VERSION" >&2
  echo "  shakapacker-webpack    = $WEBPACK_VERSION" >&2
  echo "  shakapacker-rspack     = $RSPACK_VERSION" >&2
  exit 1
fi

# Soft-warn (don't fail) if the Ruby gem version drifts from the npm
# version. The gem is published independently via `gem push`, so this
# script can't enforce gem alignment, but a mismatch usually means
# `lib/shakapacker/version.rb` was missed in the version bump commit.
GEM_VERSION="$(ruby -r ./lib/shakapacker/version -e 'puts Shakapacker::VERSION' 2>/dev/null || true)"
if [[ -n "$GEM_VERSION" && "$GEM_VERSION" != "$CORE_VERSION" ]]; then
  echo "Warning: Ruby gem version ($GEM_VERSION) does not match npm version ($CORE_VERSION)." >&2
  echo "         Update lib/shakapacker/version.rb before publishing the gem." >&2
fi

# Guardrail: prerelease versions (containing a hyphen, per semver) must not be
# published to the default `latest` dist-tag, where they would become the
# version `npm install shakapacker` picks up.
if [[ "$CORE_VERSION" == *-* && ${#TAG[@]} -eq 0 ]]; then
  echo "Refusing to publish prerelease $CORE_VERSION without --tag." >&2
  echo "Pass an explicit dist-tag, e.g.: $0 --tag next" >&2
  exit 1
fi

if [[ ${#DRY_RUN[@]} -eq 0 ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "Error: Must publish from main (currently on '$CURRENT_BRANCH')." >&2
    echo "Switch to main and re-run, or pass --dry-run to preview from another branch." >&2
    exit 1
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: Uncommitted changes detected. Commit or stash before publishing." >&2
    exit 1
  fi

  if ! npm whoami --registry https://registry.npmjs.org >/dev/null 2>&1; then
    echo "Error: not logged in to npm. Run 'npm login' first." >&2
    exit 1
  fi

  # `npm whoami` only confirms credentials, not org membership. A maintainer
  # with general npm auth but missing shakacode org access would pass the
  # whoami gate and then fail mid-run at `npm publish`, leaving partial
  # state (the same scenario `is_published` recovers from on retry — but
  # only after access is granted). Fail fast for any package that already
  # exists on the registry but isn't accessible read-write to the caller.
  # Packages not yet on the registry are skipped; the first publish creates
  # them under the caller's account.
  echo "Verifying npm publish access…"
  NPM_ACCESS_JSON="$(npm access list packages --json --registry https://registry.npmjs.org 2>/dev/null || true)"
  for pkg in shakapacker shakapacker-webpack shakapacker-rspack; do
    if npm view "$pkg" version --registry https://registry.npmjs.org >/dev/null 2>&1; then
      if ! echo "$NPM_ACCESS_JSON" | grep -Eq "\"$pkg\"[[:space:]]*:[[:space:]]*\"read-write\""; then
        echo "Error: missing read-write access to existing package '$pkg'." >&2
        echo "       Ask a shakacode npm org owner to grant publish access before retrying." >&2
        exit 1
      fi
    else
      echo "  $pkg is not yet on the registry — first publish will create it."
    fi
  done
fi

# Idempotency: if a previous run published `shakapacker` but failed before
# the supplementals (network blip, OTP timeout), retrying would hit `403
# Cannot publish over the previously published versions` on core and abort
# under `set -e`, leaving the supplementals stranded. `is_published` lets
# the script skip already-published packages and continue. Skipped under
# --dry-run since dry-runs never mutate the registry.
is_published() {
  npm view "$1@$2" version --registry https://registry.npmjs.org >/dev/null 2>&1
}

publish_package() {
  local pkg="$1"
  local version="$2"
  local dir="${3:-.}"
  if [[ ${#DRY_RUN[@]} -eq 0 ]] && is_published "$pkg" "$version"; then
    echo "  $pkg@$version already on registry — skipping."
    return
  fi
  (cd "$dir" && npm publish ${DRY_RUN[@]+"${DRY_RUN[@]}"} ${TAG[@]+"${TAG[@]}"})
}

echo "Publishing shakapacker @ $CORE_VERSION (core first)…"
publish_package shakapacker "$CORE_VERSION" .

echo "Publishing shakapacker-webpack @ $WEBPACK_VERSION…"
publish_package shakapacker-webpack "$WEBPACK_VERSION" packages/shakapacker-webpack

echo "Publishing shakapacker-rspack @ $RSPACK_VERSION…"
publish_package shakapacker-rspack "$RSPACK_VERSION" packages/shakapacker-rspack

echo "Done."
