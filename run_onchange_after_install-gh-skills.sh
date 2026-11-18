#!/usr/bin/env bash
# Install GitHub-hosted agent skills via `gh skill` for Claude Code and Codex.
# Re-runs whenever this file changes; use `gh skill update --all` to refresh.
set -euo pipefail
command -v gh >/dev/null || exit 0
gh skill --help >/dev/null 2>&1 || { echo "gh skill unavailable; upgrade gh" >&2; exit 0; }

skills=(
  "github/gh-stack gh-stack"
)

for entry in "${skills[@]}"; do
  read -r repo skill <<<"$entry"
  for agent in claude-code codex; do
    gh skill install "$repo" "$skill" --agent "$agent" --scope user --force || true
  done
done
