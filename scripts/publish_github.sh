#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="charm-agent-handoff"
OWNER="tirthbaldia"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required. Run scripts/install_gh.sh first."
  exit 1
fi

gh auth status -h github.com >/dev/null

cd "$(dirname "$0")/.."

git init

git add .
git commit -m "Initial customer hand-off pack: agent, logic apps, SQL, IaC, docs"

gh repo create "${OWNER}/${REPO_NAME}" --public --source=. --remote=origin --push

printf '\nPublished: https://github.com/%s/%s\n' "$OWNER" "$REPO_NAME"
