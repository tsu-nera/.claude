#!/usr/bin/env bash
# PreToolUse(Bash|Write|Edit): in a session that ran /issue-to-merge, `gh pr merge <n>` (or pr-land) needs the approval token
# ~/.claude/bin/merge-gate leaves for the PR's current head. The implementing session must not be the one that decides
# its PR is good enough; a human-driven /lgtm session never ran /issue-to-merge and is not affected.
set -uo pipefail

input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input")
approved_dir=${XDG_STATE_HOME:-$HOME/.local/state}/merge-gate/approved

deny() { echo "$1" >&2; exit 2; }

if [[ $tool == Write || $tool == Edit ]]; then
  [[ $(jq -r '.tool_input.file_path // empty' <<<"$input") == "$approved_dir"/* ]] \
    && deny "Approval tokens are written only by ~/.claude/bin/merge-gate."
  exit 0
fi

cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
[[ -z $cmd ]] && exit 0
# Same heredoc stripping as block-raw-gh-issue-create.sh: a PR body that mentions the command must not match.
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

grep -q 'merge-gate/approved' <<<"$code" && deny "Approval tokens are written only by ~/.claude/bin/merge-gate."

# pr-land runs gh pr merge inside, out of this hook's sight, so it counts as a merge too.
grep -qE '(^|[;&|(][[:space:]]*|^[[:space:]]*)(gh[[:space:]]+pr[[:space:]]+merge|([^[:space:]]*/)?pr-land)([[:space:]]|$)' <<<"$code" || exit 0

transcript=$(jq -r '.transcript_path // empty' <<<"$input")
[[ -f $transcript ]] || exit 0
# Only a real invocation counts (Skill tool_use or a typed/launched slash command); a plain grep also hits tool
# inputs and outputs that merely mention the skill.
jq -e -s 'any(.[];
    (.type == "assistant" and any(.message.content[]?; .type? == "tool_use" and .name == "Skill" and .input.skill == "issue-to-merge"))
    or (.type == "user" and (.message.content | type) == "string"
        and (.message.content | contains("<command-name>/issue-to-merge</command-name>"))))' \
  "$transcript" >/dev/null 2>&1 || exit 0

pr=$(grep -oP '(gh\s+pr\s+merge|pr-land)\s+#?\K[0-9]+' <<<"$code" | head -1)
[[ -n $pr ]] || deny "In an /issue-to-merge session, pass the PR number to gh pr merge / pr-land explicitly."
repo_flag=$(grep -oP '(-R|--repo)[\s=]+\K\S+' <<<"$code" | head -1)
cwd=$(jq -r '.cwd // empty' <<<"$input")
view=$(cd "${cwd:-.}" && gh pr view "$pr" ${repo_flag:+-R "$repo_flag"} --json url,headRefOid 2>&1) \
  || deny "require-merge-gate: could not read PR #$pr to check its approval: $view"
slug=$(jq -r .url <<<"$view" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/.*#\1_\2#')
sha=$(jq -r .headRefOid <<<"$view")
[[ -f $approved_dir/$slug-$pr-$sha ]] && exit 0

deny "PR #$pr has no merge-gate approval for its current head ${sha:0:10}.
In an /issue-to-merge session the merge decision belongs to an independent checker:
  ~/.claude/bin/merge-gate $pr
exit 0 approves this head; 1 means fix the findings, push and rerun; 2 means stop and leave the PR to a human.
A rebase or a new push changes the head, so rerun merge-gate after either."
