#!/usr/bin/env bash
# PreToolUse(Bash), worker sessions only (autopilot passes it via --settings): `rm` on a bare variable path
# ($T/, ${T}) makes Claude Code ask "Dangerous rm operation on possibly-empty variable path" even under
# bypassPermissions. Nobody answers in an unattended session, so it hangs for good (xchain-arb#4141, 2026-10-07).
# Denying here instead hands the agent the fix and it retries.
set -uo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
[[ -z $cmd ]] && exit 0

# Heredoc bodies are data (file contents, PR bodies), not commands.
code=$(awk '
  BEGIN { delim = "" }
  delim != "" { if ($0 == delim) { delim = "" } ; next }
  { line = $0
    if (match(line, /<<-?[[:space:]]*'"'"'?"?[A-Za-z_][A-Za-z0-9_]*'"'"'?"?/)) {
      d = substr(line, RSTART, RLENGTH)
      gsub(/^<<-?[[:space:]]*/, "", d); gsub(/['"'"'"]/, "", d)
      delim = d
    }
    print line }
' <<<"$cmd")

# Split into simple commands, keep the rm ones, and look for a $VAR / ${VAR} not guarded by ${VAR:?...}.
hit=$(sed -E 's/(&&|\|\||[;|&()])/\n/g' <<<"$code" \
  | grep -E '^[[:space:]]*(sudo[[:space:]]+)?rm([[:space:]]|$)' \
  | sed -E 's/\$\{[A-Za-z_][A-Za-z0-9_]*:\?[^}]*\}//g' \
  | grep -E '\$(\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*)' | head -1)
[[ -z $hit ]] && exit 0

echo "rm on a variable path asks for confirmation even in bypass mode, and this unattended session cannot answer it.
Rewrite the path as \"\${VAR:?}\"/... (fails fast when empty) or write it literally, then run again: ${hit}" >&2
exit 2
