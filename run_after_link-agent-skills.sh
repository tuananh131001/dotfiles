#!/usr/bin/env bash
# Link agent-expert skills into ~/.agents/skills (read by Codex and Pi).
set -euo pipefail
src="$HOME/.local/share/agent-expert/skills"
[ -d "$src" ] || exit 0
mkdir -p "$HOME/.agents/skills"
for skill in "$src"/*/; do
  target="$HOME/.agents/skills/$(basename "$skill")"
  [ -e "$target" ] && [ ! -L "$target" ] && continue
  ln -sfn "${skill%/}" "$target"
done
