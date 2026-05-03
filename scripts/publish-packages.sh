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
      TAG=(--tag "${1#--tag=}")
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

# Guardrail: prerelease versions (containing a hyphen, per semver) must not be
# published to the default `latest` dist-tag, where they would become the
# version `npm install shakapacker` picks up.
if [[ "$CORE_VERSION" == *-* && ${#TAG[@]} -eq 0 ]]; then
  echo "Refusing to publish prerelease $CORE_VERSION without --tag." >&2
  echo "Pass an explicit dist-tag, e.g.: $0 --tag next" >&2
  exit 1
fi

echo "Publishing shakapacker @ $CORE_VERSION (core first)…"
npm publish ${DRY_RUN[@]+"${DRY_RUN[@]}"} ${TAG[@]+"${TAG[@]}"}

echo "Publishing shakapacker-webpack @ $WEBPACK_VERSION…"
(cd packages/shakapacker-webpack && npm publish ${DRY_RUN[@]+"${DRY_RUN[@]}"} ${TAG[@]+"${TAG[@]}"})

echo "Publishing shakapacker-rspack @ $RSPACK_VERSION…"
(cd packages/shakapacker-rspack && npm publish ${DRY_RUN[@]+"${DRY_RUN[@]}"} ${TAG[@]+"${TAG[@]}"})

echo "Done."
