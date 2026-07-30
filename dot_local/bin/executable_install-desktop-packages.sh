#!/bin/bash
set -euo pipefail

TERMINAL_PKGS="ghostty"
GUI_PKGS="baobab gnome-disk-utility gnome-system-monitor nautilus showtime vlc"
INPUT_PKGS="fcitx5 fcitx5-unikey kcm-fcitx5"

usage() {
  cat <<EOF
Usage: $(basename "$0") <group>...

Groups:
  terminal   $TERMINAL_PKGS
  gui        $GUI_PKGS
  input      $INPUT_PKGS
  all        every group above

Examples:
  $(basename "$0") gui
  $(basename "$0") terminal input
  $(basename "$0") all
EOF
}

if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman not found; this script only supports Arch-based systems." >&2
  exit 0
fi

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

packages=""

for group in "$@"; do
  case "$group" in
    terminal) packages="$packages $TERMINAL_PKGS" ;;
    gui)      packages="$packages $GUI_PKGS" ;;
    input)    packages="$packages $INPUT_PKGS" ;;
    all)      packages="$packages $TERMINAL_PKGS $GUI_PKGS $INPUT_PKGS" ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown group: $group" >&2
      usage >&2
      exit 1
      ;;
  esac
done

packages=$(echo "$packages" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')

echo "Installing:$packages"
# shellcheck disable=SC2086
sudo pacman -S --needed $packages
