#!/bin/bash
#
# Update all submodules to the branches specified in .gitmodules
#

set -e  # Exit on error

echo "=========================================="
echo "Updating submodules to configured branches..."
echo "=========================================="

# Initialize submodules if not already done
git submodule init

# Sync .gitmodules branch configuration to .git/config
git submodule sync

# Update each submodule to its configured branch from .gitmodules
# git submodule foreach executes commands INSIDE each submodule directory
git submodule foreach '
  # Read branch from .gitmodules in the parent repo
  BRANCH=$(cd "$toplevel" && git config -f .gitmodules "submodule.$name.branch")

  # Fallback to main if no branch is configured
  if [ -z "$BRANCH" ]; then
    BRANCH="main"
  fi

  echo "→ Submodule: $name"
  echo "  Current directory: $(pwd)"
  echo "  Target branch: $BRANCH"

  # Fetch latest changes
  git fetch origin

  # Checkout configured branch
  git checkout "$BRANCH"

  # Pull latest changes
  git pull origin "$BRANCH"

  echo "  ✓ Updated to $BRANCH"
  echo ""
'

echo "=========================================="
echo "Submodule update completed!"
echo "=========================================="
