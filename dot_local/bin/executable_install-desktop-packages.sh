#!/bin/bash
set -euo pipefail

if command -v pacman >/dev/null 2>&1; then
  PM=pacman
  TERMINAL_PKGS="ghostty"
  GUI_PKGS="baobab gnome-disk-utility gnome-system-monitor nautilus showtime vlc bitwarden"
  INPUT_PKGS="fcitx5 fcitx5-unikey kcm-fcitx5"
elif command -v dnf >/dev/null 2>&1; then
  # Fedora KDE Plasma: KDE-native counterparts of the Arch GNOME apps
  # (baobab→filelight, disks→partitionmanager, nautilus→dolphin, showtime→haruna).
  PM=dnf
  TERMINAL_PKGS="ghostty" # from the scottames/ghostty COPR
  GUI_PKGS="filelight kde-partitionmanager plasma-systemmonitor dolphin haruna vlc"
  # Not in Fedora's repos; installed from Flathub when the gui group is picked.
  GUI_FLATPAKS="com.bitwarden.desktop"
  # fcitx5-configtool: standalone config UI, in case kcm-fcitx5 is uninstallable
  # (Fedora 45: built against libPlasma.so.7, repo ships .so.8).
  INPUT_PKGS="fcitx5 fcitx5-unikey kcm-fcitx5 fcitx5-configtool"
else
  echo "Neither pacman nor dnf found; only Arch and Fedora are supported." >&2
  exit 0
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") <group>...

Groups:
  terminal   $TERMINAL_PKGS
  gui        $GUI_PKGS${GUI_FLATPAKS:+ $GUI_FLATPAKS (flatpak)}
  input      $INPUT_PKGS
  all        every group above

Examples:
  $(basename "$0") gui
  $(basename "$0") terminal input
  $(basename "$0") all
EOF
}

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

packages=""
flatpaks=""

for group in "$@"; do
  case "$group" in
    terminal) packages="$packages $TERMINAL_PKGS" ;;
    gui)      packages="$packages $GUI_PKGS"; flatpaks="${GUI_FLATPAKS:-}" ;;
    input)    packages="$packages $INPUT_PKGS" ;;
    all)      packages="$packages $TERMINAL_PKGS $GUI_PKGS $INPUT_PKGS"; flatpaks="${GUI_FLATPAKS:-}" ;;
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
case "$PM" in
  pacman)
    # shellcheck disable=SC2086
    sudo pacman -Syu --needed $packages
    ;;
  dnf)
    if [[ " $packages " == *" ghostty "* ]]; then
      sudo dnf install -y 'dnf-command(copr)'
      sudo dnf copr enable -y scottames/ghostty
    fi
    # --skip-broken: one package with a dependency bug in the Fedora repos
    # (see kcm-fcitx5 above) shouldn't block the rest of the group.
    # shellcheck disable=SC2086
    sudo dnf install --skip-broken $packages
    # shellcheck disable=SC2086
    missing=$(rpm -q $packages | sed -n 's/^package \(.*\) is not installed$/\1/p' | tr '\n' ' ' || true)
    if [ -n "$missing" ]; then
      echo "WARNING: skipped (broken in Fedora repos right now): $missing" >&2
    fi
    if [[ " $packages " == *" fcitx5 "* ]]; then
      echo "fcitx5: on Plasma Wayland pick 'Fcitx 5' in System Settings → Keyboard → Virtual Keyboard, then log out and back in."
    fi
    ;;
esac

if [ -n "$flatpaks" ]; then
  echo "Installing from Flathub: $flatpaks"
  if ! command -v flatpak >/dev/null 2>&1; then
    sudo dnf install -y flatpak
  fi
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  # shellcheck disable=SC2086
  flatpak install -y flathub $flatpaks
fi
