#!/bin/bash
{
  read -r model
  read -r pct
  read -r tokens
  read -r five_pct
  read -r five_reset
} < <(jaq -r '.model.display_name, (.context_window.used_percentage // ""), (.context_window.total_input_tokens // 0), (.rate_limits.five_hour.used_percentage // ""), (.rate_limits.five_hour.resets_at // "")')

fmt=$(awk -v t="$tokens" 'BEGIN{ if (t>=1000000) printf "%.1fM", t/1000000; else if (t>=1000) printf "%.1fk", t/1000; else printf "%d", t }')

p=$(printf '%.0f' "${pct:-0}")
[ -z "$pct" ] && fmt=0

color_for() {
  if [ "$1" -ge 80 ]; then printf '\033[1;31m'
  elif [ "$1" -ge 50 ]; then printf '\033[1;33m'
  else printf '\033[1;32m'; fi
}

pc=$(color_for "$p")

left_part=$(printf '\033[1;36m%s\033[0m \033[2m|\033[0m \033[35m%s\033[0m %s(%s%%)\033[0m' "$model" "$fmt" "$pc" "$p")
right_part=""

# 5-hour session usage (only present for Claude.ai subscribers, after first API response)
if [ -n "$five_pct" ]; then
  fp=$(printf '%.0f' "$five_pct")
  fc=$(color_for "$fp")
  reset=""
  if [ -n "$five_reset" ]; then
    left=$(( ${five_reset%.*} - $(date +%s) ))
    if [ "$left" -gt 0 ]; then
      reset=$(printf ' \033[2m↻%dh%02dm\033[0m' $((left / 3600)) $(((left % 3600) / 60)))
    fi
  fi
  right_part=$(printf '\033[2m5h\033[0m %s%s%%\033[0m%s' "$fc" "$fp" "$reset")
fi

# Visible width of a string (ANSI codes stripped, multibyte-aware)
vis_len() { printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g' | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }

# Terminal width: COLUMNS, then the controlling tty, else unknown
cols=${COLUMNS:-}
[ -z "$cols" ] && cols=$({ stty size </dev/tty; } 2>/dev/null | awk '{print $2}')
[ -z "$cols" ] && cols=$(tput cols 2>/dev/null)

printf '%s' "$left_part"
if [ -n "$right_part" ]; then
  # Margin accounts for Claude Code's status line padding
  margin=4
  gap=$(( ${cols:-0} - margin - $(vis_len "$left_part") - $(vis_len "$right_part") ))
  if [ "$gap" -ge 2 ]; then
    printf '%*s%s' "$gap" '' "$right_part"
  else
    printf ' \033[2m|\033[0m %s' "$right_part"
  fi
fi
