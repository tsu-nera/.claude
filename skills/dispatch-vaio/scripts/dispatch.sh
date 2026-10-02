#!/usr/bin/env bash
# Hand non-interactive Claude jobs to vaio as background sessions (claude --bg) with Remote Control on,
# so they survive mouse going offline and can be answered from the phone / claude.ai/code when they get stuck.
#   dispatch.sh run <repo> <prompt>          one job, refused when vaio has no room (see try_launch)
#   dispatch.sh queue <repo> <prompt>...     run prompts as room frees up (detached, survives mouse offline)
#   dispatch.sh drain <repo> [--urgent] [--until HH:MM] [--skill /issue-to-pr]
#                                            work through open autopilot issues (urgent first), one at a time
#   dispatch.sh cancel <tmux-session>        stop a queue/drain from launching more (running sessions keep going)
#   dispatch.sh status                       vaio sessions with state and Remote Control URL
#   dispatch.sh clean                        stop idle sessions (they keep ~300MB each until stopped)
#   dispatch.sh res                          load / memory / agent count on mouse and vaio
set -euo pipefail

HOST=vaio
# Agents themselves are light (~300MB, ~5% CPU); the heavy part is tsc (peak 1.8GB) and vitest (all 4 cores),
# which repos serialize with their own lock (xchain-arb: prepush-checks.lock). So two agents fit as long as
# there is room for one more tsc peak plus the agent.
MAX_BUSY=2
MIN_AVAIL_MB=2500

# status/clean/res also run on vaio itself (e.g. after ssh-ing in), where "ssh vaio" would hit vaio's own sshd without a key.
on_vaio() { [[ "$(hostname)" == vaio* ]]; }
remote() { if on_vaio; then bash -l <<<"$1"; else ssh "$HOST" bash -l <<<"$1"; fi; }
agents_json() { remote 'claude agents --json'; }

prepare() {
  local repo=$1
  remote "gh auth status >/dev/null" || { echo "gh not logged in on $HOST" >&2; exit 3; }
  # Memory dir name is the project path with / and . replaced by -, identical on both machines because repos live at the same path.
  local mem="$HOME/.claude/projects/$(echo "$repo" | sed 's#[/.]#-#g')/memory/"
  if [[ -d "$mem" ]]; then
    ssh "$HOST" "mkdir -p '$mem'"
    rsync -a --delete "$mem" "$HOST:$mem"
  fi
  remote "git -C ~/.claude pull --ff-only -q && git -C '$repo' pull --ff-only -q"
  # Background sessions are interactive and refuse untrusted dirs (claude -p skipped this check).
  remote "jq -e --arg p '$repo' '.projects[\$p].hasTrustDialogAccepted' ~/.claude.json >/dev/null" \
    || { echo "$repo is not trusted on $HOST: run claude there once and accept" >&2; exit 4; }
}

# Appended to the system prompt rather than the prompt, which must stay a bare /skill invocation.
# Which operations are dangerous differs per repo, so this only states that nobody is watching and defers to the repo's rules.
WORKER_NOTE='このセッションは無人の worker で、確認できる人はいない。取り消せない操作や repo の外に影響が残る操作は、repo の規約で人の確認が要るとされているものも含めて、実行せず手前で止めて報告する。PR の作成と push は対象外（実行してよい）。'

launch_cmd() {
  printf 'cd %q && claude --bg --remote-control %q --permission-mode bypassPermissions --append-system-prompt %q %q' "$1" "$2" "$WORKER_NOTE" "$3"
}

# Shell functions shipped to vaio for both run and queue. Check and launch share one lock on vaio, and the lock is
# held until the new session shows as busy, so a run and a queue (or two queues) can't both pass the check at once.
gate_defs() {
  printf 'MAX_BUSY=%s MIN_AVAIL_MB=%s\n' "$MAX_BUSY" "$MIN_AVAIL_MB"
  cat <<'EOF'
LOCK=$HOME/.cache/dispatch-vaio.lock
busy_count() { claude agents --json | jq '[.[] | select(.status=="busy")] | length'; }
try_launch() {
  mkdir -p "$(dirname "$LOCK")"
  (
    flock 8
    busy=$(busy_count); avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
    if (( busy >= MAX_BUSY || avail < MIN_AVAIL_MB )); then
      echo "$(date +%H:%M) no room: busy $busy/$MAX_BUSY, mem avail ${avail}MB (need $MIN_AVAIL_MB)" >&2; exit 1
    fi
    (eval "$1")
    for _ in $(seq 24); do (( $(busy_count) > busy )) && break; sleep 5; done
  ) 8>"$LOCK"
}
EOF
}

cmd_run() {
  local repo prompt; repo=$(realpath "$1"); prompt=$2
  prepare "$repo"
  remote "$(gate_defs)"$'\n'"try_launch $(printf %q "$(launch_cmd "$repo" "$prompt" "$prompt")")" \
    || { echo "Run on mouse or use queue." >&2; exit 2; }
}

cmd_queue() {
  local repo; repo=$(realpath "$1"); shift
  prepare "$repo"
  local job="dispatch-queue-$(date +%m%d-%H%M%S)" runner
  runner="$(gate_defs)"$'\n'
  for p in "$@"; do
    runner+="until try_launch $(printf %q "$(launch_cmd "$repo" "$p" "$p")"); do sleep 60; done"$'\n'
  done
  ssh "$HOST" "mkdir -p ~/dispatch-logs && cat > ~/dispatch-logs/$job.sh" <<<"$runner"
  ssh "$HOST" "tmux new-session -d -s $job \"bash -l ~/dispatch-logs/$job.sh > ~/dispatch-logs/$job.log 2>&1\""
  echo "$job queued ${#} prompt(s) on $HOST (tmux session $job)"
}

# Issues are picked at launch time rather than snapshotted, so labels added or removed after starting still count.
# The drain holds one slot (it waits for its own session to go idle) so a queue started later still has room.
read -r -d '' DRAIN_DEFS <<'EOF' || true
next_issue() {
  gh issue list -l autopilot --state open --limit 100 --json number,labels \
    | jq -r --argjson urgent_only "$URGENT_ONLY" '
        map({n: .number, u: ([.labels[].name] | index("urgent") != null)})
        | map(select(.u or ($urgent_only | not))) | sort_by((if .u then 0 else 1 end), .n) | .[].n' \
    | while read -r n; do
        [[ " $TAKEN " == *" $n "* ]] && continue
        # A linked PR means someone (another drain, a manual /issue-to-merge) already took it.
        [[ -n "$(gh issue view "$n" --json closedByPullRequestsReferences -q '.closedByPullRequestsReferences[].number')" ]] && continue
        echo "$n"; break
      done
}
past_deadline() { [[ -n "$DEADLINE" ]] && (( $(date +%s) >= DEADLINE )); }
session_field() { claude agents --json | jq -r --arg id "$1" --arg f "$2" '.[] | select(.id == $id) | .[$f]'; }
drain() {
  cd "$REPO" || exit 1
  TAKEN=""
  while :; do
    past_deadline && { echo "$(date +%H:%M) deadline reached"; return; }
    n=$(next_issue)
    [[ -n "$n" ]] || { echo "$(date +%H:%M) no more issues"; return; }
    TAKEN+=" $n"
    cmd=$(launch_cmd "$REPO" "$SKILL $n" "$SKILL $n")
    until out=$(try_launch "$cmd"); do past_deadline && { echo "$(date +%H:%M) deadline reached"; return; }; sleep 60; done
    id=$(grep -o 'backgrounded · [0-9a-f]*' <<<"$out" | awk '{print $3}')
    [[ -n "$id" ]] || { echo "$(date +%H:%M) #$n launch failed: $out"; continue; }
    echo "$(date +%H:%M) #$n launched as $id"
    while [[ "$(session_field "$id" status)" == busy ]]; do sleep 60; done
    # state other than done means it stopped to ask something; it stays open for an answer, the drain moves on.
    echo "$(date +%H:%M) #$n $id idle (state: $(session_field "$id" state))"
  done
}
EOF

cmd_drain() {
  local repo; repo=$(realpath "$1"); shift
  local urgent_only=false until="" skill=/issue-to-merge
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --urgent) urgent_only=true; shift ;;
      --until) until=$2; shift 2 ;;
      --skill) skill=$2; shift 2 ;;
      *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
  done
  local deadline=""
  if [[ -n "$until" ]]; then
    deadline=$(date -d "$until" +%s)
    (( deadline > $(date +%s) )) || deadline=$(date -d "tomorrow $until" +%s)
  fi
  prepare "$repo"
  local job="dispatch-drain-$(date +%m%d-%H%M%S)" runner
  runner="$(gate_defs)"$'\n'"$(declare -p WORKER_NOTE)"$'\n'"$(declare -f launch_cmd)"$'\n'"$DRAIN_DEFS"$'\n'
  runner+="REPO=$(printf %q "$repo") SKILL=$(printf %q "$skill") URGENT_ONLY=$urgent_only DEADLINE=$deadline"$'\n'"drain"$'\n'
  ssh "$HOST" "mkdir -p ~/dispatch-logs && cat > ~/dispatch-logs/$job.sh" <<<"$runner"
  ssh "$HOST" "tmux new-session -d -s $job \"bash -l ~/dispatch-logs/$job.sh > ~/dispatch-logs/$job.log 2>&1\""
  echo "$job started on $HOST (urgent only: $urgent_only, until: ${until:-none}, skill: $skill). Log: ~/dispatch-logs/$job.log"
}

cmd_cancel() {
  remote "tmux kill-session -t $(printf %q "$1")" && echo "cancelled $1 (sessions it already launched keep running; see status)"
}

cmd_status() {
  agents_json | jq -r --argjson now "$(date +%s)" '.[] | "\(.id // .sessionId[:8])  \(.status)/\(.state // "-")  \((($now - .startedAt/1000) / 60 | floor))m  \(.name)"' | while read -r id rest; do
    url=$(remote "claude logs $id 2>/dev/null | grep -o 'https://claude.ai/code/session_[A-Za-z0-9]*' | tail -1" || true)
    echo "$id  $rest  ${url:-}"
  done
  remote "for s in \$(tmux ls -F '#{session_name}' 2>/dev/null | grep '^dispatch-'); do echo \"tmux: \$s  \$(tail -1 ~/dispatch-logs/\$s.log 2>/dev/null)\"; done" || true
}

cmd_clean() {
  agents_json | jq -r '[.[] | select(.kind=="background" and .status=="idle") | .id] | unique | .[]' | while read -r id; do
    remote "claude stop $id" >/dev/null && echo "stopped $id"
  done
}

# One line per host so mouse and vaio compare at a glance. Bracketed patterns keep pgrep from matching this probe itself.
read -r -d '' RES_PROBE <<'PROBE' || true
read -r _ mt _ <<<"$(free -g | grep Mem)"; ma=$(free -g | awk '/Mem/{print $7}'); sw=$(free -g | awk '/Swap/{print $3}')
printf '%-8s load %s/%s  mem avail %sG/%sG  swap %sG  claude %s  heavy(tsc/vitest) %s\n' \
  "$(hostname -s | cut -c1-8)" "$(cut -d' ' -f1 /proc/loadavg)" "$(nproc)" "$ma" "$mt" "$sw" \
  "$(pgrep -cx claude)" "$(pgrep -cf '[t]sc |[v]itest')"
PROBE

cmd_res() {
  if on_vaio; then bash <<<"$RES_PROBE"; return; fi
  bash <<<"$RES_PROBE"
  ssh "$HOST" bash <<<"$RES_PROBE"
}

case "${1:-}" in
  run|queue|drain) on_vaio && { echo "run/queue/drain are for mouse; vaio is the worker" >&2; exit 1; } ;;
esac

case "${1:-}" in
  run) shift; [[ $# -eq 2 ]] || { echo "usage: dispatch.sh run <repo> <prompt>" >&2; exit 1; }; cmd_run "$@" ;;
  queue) shift; [[ $# -ge 2 ]] || { echo "usage: dispatch.sh queue <repo> <prompt>..." >&2; exit 1; }; cmd_queue "$@" ;;
  drain) shift; [[ $# -ge 1 ]] || { echo "usage: dispatch.sh drain <repo> [--urgent] [--until HH:MM] [--skill /issue-to-pr]" >&2; exit 1; }; cmd_drain "$@" ;;
  cancel) shift; [[ $# -eq 1 ]] || { echo "usage: dispatch.sh cancel <tmux-session>" >&2; exit 1; }; cmd_cancel "$1" ;;
  status) cmd_status ;;
  clean) cmd_clean ;;
  res) cmd_res ;;
  *) sed -n '2,11p' "$0"; exit 1 ;;
esac
