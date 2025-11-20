#!/bin/bash
# Reproduce CI checks locally
# Based on .github/workflows/*.yml

set -e

echo "========================================="
echo "Running CI Checks Locally"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED_CHECKS=()

run_check() {
  local check_name="$1"
  shift
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Running: $check_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if "$@"; then
    echo -e "${GREEN}✓ PASSED:${NC} $check_name"
  else
    echo -e "${RED}✗ FAILED:${NC} $check_name"
    FAILED_CHECKS+=("$check_name")
    return 1
  fi
}

# Node/TypeScript checks
echo -e "${YELLOW}Node/TypeScript Checks${NC}"
run_check "ESLint" yarn lint || true
run_check "Prettier" yarn prettier --check . || true
run_check "TypeScript" yarn type-check || true
run_check "Knip (dead code)" yarn knip || true
run_check "Knip Production" yarn knip:production || true
run_check "Jest Tests" yarn test || true

# Ruby checks
echo ""
echo -e "${YELLOW}Ruby Checks${NC}"
run_check "RuboCop" bundle exec rubocop || true
run_check "RSpec" bundle exec rspec || true

echo ""
echo "========================================="
echo "Summary"
echo "========================================="

if [ ${#FAILED_CHECKS[@]} -eq 0 ]; then
  echo -e "${GREEN}All checks passed!${NC}"
  exit 0
else
  echo -e "${RED}Failed checks (${#FAILED_CHECKS[@]}):${NC}"
  for check in "${FAILED_CHECKS[@]}"; do
    echo -e "  ${RED}✗${NC} $check"
  done
  exit 1
fi
