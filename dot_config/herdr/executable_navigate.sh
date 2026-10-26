#!/usr/bin/env bash
# Smart pane navigation (vim-tmux-navigator style).
# Usage: navigate.sh <left|down|up|right>
# If the focused pane runs (n)vim, forward ctrl+<hjkl> to it so nvim can move
# between its own splits; otherwise focus the neighboring herdr pane.

direction="$1"
herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_ACTIVE_PANE_ID:-}"

case "$direction" in
left) key="ctrl+h" ;;
down) key="ctrl+j" ;;
up) key="ctrl+k" ;;
right) key="ctrl+l" ;;
*) exit 1 ;;
esac

[ -z "$pane" ] && exit 1

if "$herdr" pane process-info --pane "$pane" |
	grep -Eq '"argv0":"([^"]*/)?(n?vim?x?|vimdiff)"'; then
	"$herdr" pane send-keys "$pane" "$key"
else
	"$herdr" pane focus --pane "$pane" --direction "$direction"
fi
