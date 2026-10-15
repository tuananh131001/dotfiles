#!/bin/bash
{
  read -r model
  read -r pct
  read -r tokens
} < <(jaq -r '.model.display_name, (.context_window.used_percentage // ""), (.context_window.total_input_tokens // 0)')

fmt=$(awk -v t="$tokens" 'BEGIN{ if (t>=1000000) printf "%.1fM", t/1000000; else if (t>=1000) printf "%.1fk", t/1000; else printf "%d", t }')

p=$(printf '%.0f' "${pct:-0}")
[ -z "$pct" ] && fmt=0

if [ "$p" -ge 80 ]; then
  pc='\033[1;31m'
elif [ "$p" -ge 50 ]; then
  pc='\033[1;33m'
else
  pc='\033[1;32m'
fi

printf '\033[1;36m%s\033[0m \033[2m|\033[0m \033[35m%s\033[0m '"$pc"'(%s%%)\033[0m' "$model" "$fmt" "$p"
