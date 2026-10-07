# Sourced by autopilot: how a stopped job reaches someone. The Discord log channel always; the agent watching from mouse
# when there is one (it acks what it receives); #hitl only when nobody acked in time.

# Blocks until the loop needs someone: a job blocked, handed back a question or failed, or the loop ended for any reason.
# Meant for run_in_background from mouse, so unlike every other command it polls from the calling host: each poll acks the
# lines it receives, and the loop sends to #hitl only what nobody picked up. A watcher kept on the worker over one long ssh
# could not prove that: it outlives a mouse gone to sleep. A failed poll is retried, since the loop runs on regardless.
cmd_watch() {
  local name=${1:?usage: autopilot watch <repo>} seen=- got="" out lines at count loop rest
  name=${name##*/}
  while :; do
    if [[ "$(hostname)" == ${HOST}* ]]; then out=$("$0" _watch-tick "$name" "$seen")
    else out=$(ssh "$HOST" "bash -lc $(printf %q "$(printf '%q ' autopilot _watch-tick "$name" "$seen")")"); fi
    if (( $? )); then [[ $seen == - ]] && return 1; sleep "$WATCH_POLL"; continue; fi
    lines=$(grep -v '^@@ ' <<<"$out")
    read -r at count loop rest <<<"$(grep '^@@ ' <<<"$out" | tail -1)"
    [[ $count =~ ^[0-9]+$ ]] && seen=$count
    [[ -n $lines ]] && got+="$lines"$'\n'
    if [[ $loop == ended ]]; then printf '%s' "$got"; echo "loop ended: $rest"; return 0; fi
    if grep -qE '^\S+ \S+ (blocked|answer|failed) ' <<<"$lines"; then printf '%s' "$got"; echo "loop: running"; return 0; fi
    sleep "$WATCH_POLL"
  done
}

notify() {
  [[ -s $WEBHOOK_FILE ]] || return 0
  jq -n --arg c "$1" '{content: $c}' | curl -fsS -m 10 -H 'Content-Type: application/json' -d @- "$(cat "$WEBHOOK_FILE")" >/dev/null \
    || echo "$(now) warning: discord notify failed" >&2
}
# Also to #hitl: only for states the user has to act on (the autopilot channel is a log stream).
# [needs-answer] is left out here: hitl-scan picks up the label itself.
# Args: tag, head (job label and issue/PR lines), what happened, what to decide, where to answer (empty: vaio-ops).
# Call it after record: the #hitl part waits for a watch to ack that history line and is dropped if one does (the agent
# on mouse got it). It runs detached so a loop ending right after (HALTED) does not take it down with its tmux session.
notify_hitl() {
  notify "[$1] $2"
  setsid -f "$SELF" _escalate "$st" "$(wc -l <"$st/history")" "$@" >>"$st/log" 2>&1
}
cmd_escalate() {
  local st=$1 line=$2; shift 2
  sleep "$ACK_WAIT"
  if (( $(cat "$st/acked" 2>/dev/null || echo 0) >= line )); then echo "$(now) [$1] picked up by watch, not sent to #hitl"; return; fi
  "$HOME/.claude/bin/hitl" ask "$2" "$1: $3" "$4" "${5:-}"
}
# Remote Control URL of a session: where its question can be answered from the phone. Empty once the session is stopped.
rc_url() { claude logs "$1" 2>/dev/null | grep -o 'https://claude.ai/code/session_[A-Za-z0-9]*' | tail -1; }
# The transcript is named by the full session id, of which the agent id is the prefix; it stays after the session stops.
transcript() { ls "$HOME"/.claude/projects/*/"$1"-*.jsonl 2>/dev/null | head -1; }
# Last assistant turn with text, whitespace folded and cut to 300 chars, as "<api error kind or ->\t<text>".
# Claude Code writes an API failure as a synthetic assistant turn flagged isApiErrorMessage.
last_said() {
  jq -r 'select(.type == "assistant")
    | [(if .isApiErrorMessage then .error // "unknown" else "-" end),
       ([.message.content[]? | select(.type == "text") | .text] | join(" ") | gsub("\\s+"; " ") | .[0:300])]
    | select(.[1] != "") | @tsv' "$1" | tail -1
}
said() { local f; f=$(transcript "$1"); if [[ -n $f ]]; then last_said "$f" | cut -f2-; else echo "(transcript なし)"; fi; }

# One poll of `watch`. With <seen> "-" it only checks there is a loop to watch; otherwise it prints the history lines after
# <seen> and acks them for the loop (see notify_hitl). The last line is "@@ <lines> running" or "@@ <lines> ended <last-exit>".
cmd_watch_tick() {
  local name=${1:?usage: autopilot _watch-tick <repo> <seen|->} seen=${2:-} st new count
  name=${name##*/}; repo_dir "$name" >/dev/null; st=$(repo_state "$name"); touch "$st/history"
  if [[ $seen == - ]]; then
    tmux has-session -t "autopilot-$name" 2>/dev/null || die "no loop running for $name (last: $(cat "$st/last-exit" 2>/dev/null || echo -))"
    count=$(wc -l <"$st/history")
  else
    # Read once and count what was read: a line appended meanwhile is left for the next poll instead of acked unseen.
    new=$(tail -n +$((seen + 1)) "$st/history"); count=$seen
    if [[ -n $new ]]; then printf '%s\n' "$new"; count=$(( seen + $(wc -l <<<"$new") )); fi
    echo "$count" >"$st/acked"
  fi
  if tmux has-session -t "autopilot-$name" 2>/dev/null; then echo "@@ $count running"
  else echo "@@ $count ended $(cat "$st/last-exit" 2>/dev/null || echo -)"; fi
}
