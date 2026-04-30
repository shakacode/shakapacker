#!/usr/bin/env bash
# Publish core shakapacker first, then the supplemental packages.
#
# Sequencing is load-bearing: shakapacker-webpack and shakapacker-rspack both
# declare "shakapacker": "^X.Y.Z" as a required peer dep. Publishing a
# supplemental before core leaves installers with an unresolvable peer dep
# until core is published.
#
# Usage:
#   ./scripts/publish-packages.sh           # publish all three at the version in root package.json
#   ./scripts/publish-packages.sh --dry-run # preview without publishing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=()
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=(--dry-run)
fi

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

echo "Publishing shakapacker @ $CORE_VERSION (core first)…"
npm publish ${DRY_RUN[@]+"${DRY_RUN[@]}"}

echo "Publishing shakapacker-webpack @ $WEBPACK_VERSION…"
(cd packages/shakapacker-webpack && npm publish ${DRY_RUN[@]+"${DRY_RUN[@]}"})

echo "Publishing shakapacker-rspack @ $RSPACK_VERSION…"
(cd packages/shakapacker-rspack && npm publish ${DRY_RUN[@]+"${DRY_RUN[@]}"})

echo "Done."
