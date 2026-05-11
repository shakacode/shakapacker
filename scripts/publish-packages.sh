#!/usr/bin/env bash
# Publish core shakapacker first, then the supplemental packages.
#
# Sequencing is load-bearing: shakapacker-webpack and shakapacker-rspack both
# declare "shakapacker": "~X.Y.Z" as a regular dependency. Publishing a
# supplemental before core leaves `npm install shakapacker-webpack` unable to
# resolve the dependency tree until core is published.
#
# Normal usage is via `bundle exec rake "release[X.Y.Z]"`, which wraps this
# script after release-it bumps versions and pushes the release commit. Direct
# invocation below is supported for manual recovery (e.g. retrying after a
# partial publish) or for CI workflows that publish without bumping.
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
#
# Supply-chain provenance: when run from GitHub Actions with `id-token: write`,
# the script auto-detects the environment and adds `--provenance` to the publish
# call. This generates an SLSA-2 provenance attestation that links each
# published artifact to the workflow run that built it. Local publishes skip
# the flag (publishing without an OIDC token fails fast otherwise).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=()
TAG=()
PROVENANCE=()
# GitHub Actions sets ACTIONS_ID_TOKEN_REQUEST_URL when `id-token: write`
# permission is granted. Use that as the signal — outside CI the env var
# is absent and `npm publish --provenance` would fail with a clearer
# "Missing OIDC token" error than we'd want to surface here.
if [[ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]]; then
  PROVENANCE=(--provenance)
fi
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

# Supplementals declare `"shakapacker": "~X.Y.Z"` as a regular dependency.
# `npm version` (run by the release rake task) bumps only the `version`
# field — without a parallel bump of this constraint, a 10.1.0 → 10.2.0
# release would publish supplementals declaring `~10.1.0` (which resolves
# to >=10.1.0 <10.2.0 — unable to install the new core). The rake task
# does that rewrite; this check is the publish-time guard that catches
# any path that bypassed the rake flow.
WEBPACK_CORE_DEP="$(node -p "require('./packages/shakapacker-webpack/package.json').dependencies.shakapacker")"
RSPACK_CORE_DEP="$(node -p "require('./packages/shakapacker-rspack/package.json').dependencies.shakapacker")"
EXPECTED_CORE_DEP="~$CORE_VERSION"
if [[ "$WEBPACK_CORE_DEP" != "$EXPECTED_CORE_DEP" || "$RSPACK_CORE_DEP" != "$EXPECTED_CORE_DEP" ]]; then
  echo "Core-dependency mismatch — supplementals must declare 'shakapacker': '$EXPECTED_CORE_DEP':" >&2
  echo "  shakapacker-webpack    -> $WEBPACK_CORE_DEP" >&2
  echo "  shakapacker-rspack     -> $RSPACK_CORE_DEP" >&2
  echo "  expected               -> $EXPECTED_CORE_DEP" >&2
  exit 1
fi

# Soft-warn (don't fail) if the Ruby gem version drifts from the npm
# version. The gem is published independently via `gem push`, so this
# script can't enforce gem alignment, but a mismatch usually means
# `lib/shakapacker/version.rb` was missed in the version bump commit.
#
# Compare in npm syntax (10.1.0-beta.1) rather than gem syntax
# (10.1.0.beta.1) — a raw string compare would false-warn on every
# prerelease release because the two syntaxes differ on the prerelease
# separator (`-` vs `.`).
GEM_VERSION_NPM="$(ruby -r ./lib/shakapacker/utils/version_syntax_converter -e 'puts Shakapacker::Utils::VersionSyntaxConverter.new.rubygem_to_npm' 2>/dev/null || true)"
if [[ -n "$GEM_VERSION_NPM" && "$GEM_VERSION_NPM" != "$CORE_VERSION" ]]; then
  GEM_VERSION_RAW="$(ruby -r ./lib/shakapacker/version -e 'puts Shakapacker::VERSION' 2>/dev/null || true)"
  echo "Warning: Ruby gem version ($GEM_VERSION_RAW → $GEM_VERSION_NPM in npm syntax) does not match npm version ($CORE_VERSION)." >&2
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
  # only after access is granted). When npm access list is available, fail
  # fast for any already-published package the caller can't write to.
  #
  # `npm access list packages` is unreliable for unscoped packages on some
  # npm versions: it can return an empty result even when the caller has
  # full publish rights. When the response is empty (registry blip,
  # unsupported subcommand, or unscoped-package limitation) we soft-warn
  # rather than hard-fail; an actual access failure still surfaces as a
  # clear 403 from `npm publish`, and the `is_published` idempotency guard
  # makes retrying after access is granted safe.
  echo "Verifying npm publish access…"
  NPM_ACCESS_JSON="$(npm access list packages --json --registry https://registry.npmjs.org 2>/dev/null || true)"
  if [[ -z "$NPM_ACCESS_JSON" ]]; then
    echo "Warning: could not fetch npm access list (registry error or unscoped-package limitation)." >&2
    echo "         If publish fails with 403, ask a shakacode npm org owner to grant access." >&2
  else
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
fi

# Idempotency: if a previous run published `shakapacker` but failed before
# the supplementals (network blip, OTP timeout), retrying would hit `403
# Cannot publish over the previously published versions` on core and abort
# under `set -e`, leaving the supplementals stranded. `is_published` lets
# the script skip already-published packages and continue. Skipped under
# --dry-run since dry-runs never mutate the registry.
is_published() {
  # Best-effort: `npm view` returns non-zero for both "not published yet"
  # (expected) and "registry unreachable" (transient). On the transient
  # path we fall through to `npm publish`, which will surface the
  # underlying error itself; a follow-up run is safe because the next
  # `is_published` check skips anything that did publish.
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
  # Pin the publish target to npmjs.org explicitly so the script doesn't
  # accidentally follow a maintainer's `.npmrc` to a private registry. All
  # pre-flight checks above already pass `--registry`; matching that here
  # keeps validation and publish targeting the same registry.
  (cd "$dir" && npm publish --registry=https://registry.npmjs.org ${DRY_RUN[@]+"${DRY_RUN[@]}"} ${TAG[@]+"${TAG[@]}"} ${PROVENANCE[@]+"${PROVENANCE[@]}"})
}

echo "Publishing shakapacker @ ${CORE_VERSION} (core first)…"
publish_package shakapacker "$CORE_VERSION" .

echo "Publishing shakapacker-webpack @ ${WEBPACK_VERSION}…"
publish_package shakapacker-webpack "$WEBPACK_VERSION" packages/shakapacker-webpack

echo "Publishing shakapacker-rspack @ ${RSPACK_VERSION}…"
publish_package shakapacker-rspack "$RSPACK_VERSION" packages/shakapacker-rspack

echo "Done."
