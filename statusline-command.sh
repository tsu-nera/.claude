#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Replace $HOME with ~ in cwd
case "$cwd" in
  "$HOME") cwd="~" ;;
  "$HOME"/*) cwd="~${cwd#$HOME}" ;;
esac

# PS1-style: bold blue cwd, reset
ps1_part=$(printf '\033[01;34m%s\033[00m' "$cwd")

# Claude context info
if [ -n "$used" ]; then
  ctx_part=$(printf ' \033[00;33m[%s | ctx:%s%%]\033[00m' "$model" "$(printf '%.0f' "$used")")
else
  ctx_part=$(printf ' \033[00;33m[%s]\033[00m' "$model")
fi

# Rate limits (Pro/Max subscription only)
limits=""
if [ -n "$five_h" ]; then
  five_h_str="5h:$(printf '%.0f' "$five_h")%"
  [ -n "$five_h_reset" ] && five_h_str="$five_h_str(→$(date -d "@$five_h_reset" +%H:%M 2>/dev/null))"
  limits="$five_h_str"
fi
[ -n "$week" ] && limits="${limits:+$limits }7d:$(printf '%.0f' "$week")%"
if [ -n "$limits" ]; then
  rate_part=$(printf ' \033[00;36m[%s]\033[00m' "$limits")
else
  rate_part=""
fi

printf '%s%s%s' "$ps1_part" "$ctx_part" "$rate_part"
