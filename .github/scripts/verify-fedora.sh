#!/bin/bash
# Assert a Fedora `chezmoi init --apply` (+ optional desktop install) worked.
# Usage: verify-fedora.sh [--desktop]
set -uo pipefail
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
fail=0
ok()  { printf 'PASS  %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

grep -E '^(PRETTY_NAME)=' /etc/os-release; uname -m

# Core CLIs: Fedora repos (dnf), mise (Fedora-only tools), curl installers.
for c in git gh chezmoi nvim rg 7z tree-sitter zoxide jq fish fzf mpv \
         sk btm jaq sops yazi bw starship mise croc; do
  if v=$(command -v "$c"); then ok "cmd $c -> $v"; else bad "cmd $c missing"; fi
done
for c in sk btm jaq sops yazi bw; do
  check "$c runs (--version)" "$c" --version
done

check "Geist Mono Nerd Font registered with fontconfig" sh -c 'fc-list | grep -q "GeistMono Nerd Font"'
check "mise config has Fedora tools" grep -q '^skim = "latest"' ~/.config/mise/config.toml
check "claude settings.json has statusLine (jq fallback/jaq)" \
  jq -e '.statusLine.command == "bash ~/.claude/statusline-command.sh"' ~/.claude/settings.json
check "fish config deployed" test -f ~/.config/fish/config.fish
check "desktop installer deployed + executable" test -x ~/.local/bin/install-desktop-packages.sh
check "no hammerspoon on Linux" test ! -e ~/.hammerspoon

if [ "${1:-}" = "--desktop" ]; then
  for p in ghostty filelight kde-partitionmanager plasma-systemmonitor dolphin haruna vlc \
           fcitx5 fcitx5-unikey fcitx5-configtool; do
    if v=$(rpm -q "$p"); then ok "rpm $v"; else bad "rpm $p not installed"; fi
  done
  # kcm-fcitx5 is allowed to be skipped only while Fedora can't resolve it.
  # (capture first: dnf exits 1 here, which would fail a pipefail pipeline)
  kcm_err=$(dnf -q install --assumeno kcm-fcitx5 2>&1)
  if v=$(rpm -q kcm-fcitx5); then ok "rpm $v"
  elif [[ $kcm_err == *"nothing provides"* ]]; then
    ok "kcm-fcitx5 skipped: uninstallable in Fedora repos ($(grep -o 'nothing provides [^ ]*' <<<"$kcm_err"))"
  else bad "rpm kcm-fcitx5 not installed (and it IS installable)"; fi
  check "ghostty --version" ghostty --version
  check "fcitx5 --version" fcitx5 --version
  check "unikey addon registered" test -f /usr/share/fcitx5/addon/unikey.conf
  check "dolphin --version (offscreen)" env QT_QPA_PLATFORM=offscreen dolphin --version
  check "filelight --version (offscreen)" env QT_QPA_PLATFORM=offscreen filelight --version
fi

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit "$fail"
