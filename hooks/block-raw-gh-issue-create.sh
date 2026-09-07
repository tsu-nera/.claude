#!/usr/bin/env bash
# PreToolUse(Bash): force every issue creation through ~/.claude/bin/create-issue.sh.
# The skill's doctrine is otherwise silently bypassed -- the raw command is reachable
# without ever reading it, which is how three issues got created off-doctrine on 2026-09-07.
set -uo pipefail

cmd="$(jq -r '.tool_input.command // empty')"
[[ -z "$cmd" ]] && exit 0

# A hook only ever sees the raw command string, heredoc bodies included, so a commit message
# or issue body that merely mentions the command would match (it did, on the very first try).
# Drop heredoc bodies before matching.
code="$(awk '
  BEGIN { delim = "" }
  delim != "" { if ($0 == delim) { delim = "" } ; next }
  { line = $0
    if (match(line, /<<-?[[:space:]]*'"'"'?"?[A-Za-z_][A-Za-z0-9_]*'"'"'?"?/)) {
      d = substr(line, RSTART, RLENGTH)
      gsub(/^<<-?[[:space:]]*/, "", d); gsub(/['"'"'"]/, "", d)
      delim = d
    }
    print line }
' <<<"$cmd")"

if grep -qE '(^|[;&|(][[:space:]]*|^[[:space:]]*)gh[[:space:]]+issue[[:space:]]+create([[:space:]]|$)' <<<"$code"; then
  cat >&2 <<'MSG'
Raw `gh issue create` is blocked. Issue creation must go through the create-issue skill.

1. Decide the mode from the user's own words (skill Step 0): "issue立てて" -> ready / "とりあえず" -> draft. When unsure, draft.
2. ready mode: read ~/.claude/skills/create-issue/references/ready.md first.
3. Create with:
   ~/.claude/bin/create-issue.sh --mode <ready|draft> --repo <owner/repo> --title "<title>" --body-file <path> --label <label>
MSG
  exit 2
fi
exit 0
