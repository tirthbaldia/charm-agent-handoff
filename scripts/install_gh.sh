#!/usr/bin/env bash
set -euo pipefail

if command -v gh >/dev/null 2>&1; then
  echo "gh already installed: $(gh --version | head -n1)"
else
  brew install gh
fi

echo "Run: gh auth login -h github.com -w"
echo "Then verify: gh auth status -h github.com"
