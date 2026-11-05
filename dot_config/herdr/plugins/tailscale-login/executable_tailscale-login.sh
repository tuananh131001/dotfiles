#!/usr/bin/env bash
# tailscale-login: open the Tailscale login page when the local tailscaled
# drops into NeedsLogin (happens after sleep / long uptime), so herdr's SSH
# machines (reached through tailscaled's SOCKS5 proxy) can reconnect.
#
#   tailscale-login.sh watch           loop forever (run by the launchd agent)
#   tailscale-login.sh once            run a single watch iteration
#   tailscale-login.sh login           start interactive login now and open the URL
#   tailscale-login.sh status          show backend state as a herdr notification
#   tailscale-login.sh ensure-agent    install/refresh + load the launchd agent
#   tailscale-login.sh remove-agent    unload + delete the launchd agent
#
# Optional config: $CONFIG_DIR/config.sh (shell vars below can be overridden).
set -u

PLUGIN_ID="${HERDR_PLUGIN_ID:-local.tailscale-login}"
PLUGIN_ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
HERDR="${HERDR_BIN_PATH:-$(command -v herdr || echo /opt/homebrew/bin/herdr)}"
CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-${TSL_CONFIG_DIR:-}}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-${TSL_STATE_DIR:-$HOME/.cache/herdr-tailscale-login}}"

# Defaults -------------------------------------------------------------------
TS_SOCKET="/var/run/tailscaled.socket"
INTERVAL=10          # seconds between state checks
RETRIGGER=300        # seconds before re-requesting a login URL while still NeedsLogin
REOPEN=900           # seconds before re-opening the same URL if still not logged in
OPEN_CMD="/usr/bin/open"
NOTIFY=1             # 1 = also show a herdr notification

[ -n "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/config.sh" ] && . "$CONFIG_DIR/config.sh"

LABEL="dev.herdr.tailscale-login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/herdr-tailscale-login.log"

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*"; }

notify() {
  [ "$NOTIFY" = 1 ] || return 0
  "$HERDR" notification show "Tailscale" --body "$1" --sound none >/dev/null 2>&1 || true
}

localapi() { # method path
  curl -fsS --max-time 5 --unix-socket "$TS_SOCKET" -H 'Host: local-tailscaled.sock' \
    -X "$1" "http://local-tailscaled.sock/localapi/v0/$2"
}

# Prints "<BackendState>\t<AuthURL>"; TSL_FAKE_STATUS=<file> is for testing.
read_state() {
  local json
  if [ -n "${TSL_FAKE_STATUS:-}" ]; then json=$(cat "$TSL_FAKE_STATUS") || return 1
  else json=$(localapi GET 'status?peers=false' 2>/dev/null) || return 1
  fi
  printf '%s' "$json" | /usr/bin/python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("BackendState", "") + "\t" + (d.get("AuthURL") or ""))'
}

start_login() {
  if [ -n "${TSL_FAKE_STATUS:-}" ]; then log "fake: login-interactive"; return 0; fi
  localapi POST login-interactive >/dev/null 2>&1
}

open_url() {
  case "$1" in https://*) ;; *) log "refusing non-https url: $1"; return 1 ;; esac
  $OPEN_CMD "$1" >/dev/null 2>&1
}

# Waits up to ~10s for tailscaled to publish an AuthURL; prints it.
wait_for_url() {
  local i st url
  for i in 1 2 3 4 5 6 7 8 9 10; do
    IFS=$'\t' read -r st url < <(read_state) || true
    [ "${st:-}" != NeedsLogin ] && return 1
    [ -n "${url:-}" ] && { printf '%s\n' "$url"; return 0; }
    sleep 1
  done
  return 1
}

# Watch state (kept across iterations / in files for `once`).
mkdir -p "$STATE_DIR"
last_url=$(cat "$STATE_DIR/last_url" 2>/dev/null || true)
last_open=$(cat "$STATE_DIR/last_open" 2>/dev/null || echo 0)
last_trigger=$(cat "$STATE_DIR/last_trigger" 2>/dev/null || echo 0)
save() {
  printf '%s' "$last_url" >"$STATE_DIR/last_url"
  printf '%s' "$last_open" >"$STATE_DIR/last_open"
  printf '%s' "$last_trigger" >"$STATE_DIR/last_trigger"
}

tick() {
  local st url now
  IFS=$'\t' read -r st url < <(read_state) || return 0   # tailscaled down: try later
  now=$(date +%s)
  if [ "$st" != NeedsLogin ]; then
    if [ -n "$last_url" ] || [ "$last_trigger" != 0 ]; then
      log "state=$st, login no longer needed"
      [ -n "$last_url" ] && notify "Logged in ($st)"
      last_url=""; last_open=0; last_trigger=0; save
    fi
    return 0
  fi
  if [ -z "$url" ]; then
    (( now - last_trigger < RETRIGGER )) && return 0
    log "state=NeedsLogin, requesting login URL"
    last_trigger=$now; save
    start_login || { log "login-interactive failed"; return 0; }
    url=$(wait_for_url) || { log "no AuthURL yet"; return 0; }
  fi
  if [ "$url" != "$last_url" ] || (( now - last_open >= REOPEN )); then
    log "opening $url"
    open_url "$url" && { last_url=$url; last_open=$now; save; }
    notify "Login required: opened $url"
  fi
}

ensure_agent() {
  local tmp
  mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
  [ -z "$CONFIG_DIR" ] && CONFIG_DIR=$("$HERDR" plugin config-dir "$PLUGIN_ID" 2>/dev/null || true)
  tmp=$(mktemp)
  cat >"$tmp" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$PLUGIN_ROOT/tailscale-login.sh</string>
    <string>watch</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HERDR_BIN_PATH</key><string>$HERDR</string>
    <key>TSL_CONFIG_DIR</key><string>$CONFIG_DIR</string>
    <key>TSL_STATE_DIR</key><string>$STATE_DIR</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST
  if ! cmp -s "$tmp" "$PLIST"; then
    mv "$tmp" "$PLIST"
    launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
    echo "installed $PLIST"
  else
    rm -f "$tmp"
  fi
  if ! launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
    launchctl bootstrap "gui/$(id -u)" "$PLIST" && echo "loaded $LABEL"
  fi
}

case "${1:-}" in
  watch)
    log "watcher started (interval=${INTERVAL}s)"
    while true; do tick; sleep "$INTERVAL"; done ;;
  once) tick ;;
  login)
    IFS=$'\t' read -r st url < <(read_state) || { notify "tailscaled is not reachable"; exit 1; }
    if [ "$st" != NeedsLogin ]; then notify "Already logged in ($st)"; exit 0; fi
    [ -z "$url" ] && { start_login; url=$(wait_for_url); }
    if [ -n "${url:-}" ] && open_url "$url"; then
      last_url=$url; last_open=$(date +%s); save; notify "Opened $url"
    else
      notify "Could not get a Tailscale login URL"; exit 1
    fi ;;
  status)
    IFS=$'\t' read -r st url < <(read_state) || { notify "tailscaled is not reachable"; exit 1; }
    notify "State: $st${url:+ — $url}"; printf '%s\t%s\n' "$st" "$url" ;;
  ensure-agent) ensure_agent ;;
  remove-agent)
    launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
    rm -f "$PLIST"; echo "removed $LABEL" ;;
  *) echo "usage: $0 watch|once|login|status|ensure-agent|remove-agent" >&2; exit 2 ;;
esac
