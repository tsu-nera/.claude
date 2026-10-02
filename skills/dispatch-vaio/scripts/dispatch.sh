#!/usr/bin/env bash
# Hand non-interactive Claude jobs to vaio as background sessions (claude --bg) with Remote Control on,
# so they survive mouse going offline and can be answered from the phone / claude.ai/code when they get stuck.
#   dispatch.sh run <repo> <prompt>          one job, refused while another vaio session is busy
#   dispatch.sh queue <repo> <prompt>...     run prompts one after another (detached, survives mouse offline)
#   dispatch.sh status                       vaio sessions with state and Remote Control URL
#   dispatch.sh clean                        stop idle sessions (they keep ~300MB each until stopped)
#   dispatch.sh res                          load / memory / agent count on mouse and vaio
set -euo pipefail

HOST=vaio
MAX_BUSY=1

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

launch_cmd() {
  printf 'cd %q && claude --bg --remote-control %q --permission-mode bypassPermissions %q' "$1" "$2" "$3"
}

cmd_run() {
  local repo prompt; repo=$(realpath "$1"); prompt=$2
  local busy; busy=$(agents_json | jq '[.[] | select(.status=="busy")] | length')
  if (( busy >= MAX_BUSY )); then echo "vaio busy ($busy session(s)). Run on mouse or use queue." >&2; exit 2; fi
  prepare "$repo"
  remote "$(launch_cmd "$repo" "$prompt" "$prompt")"
}

cmd_queue() {
  local repo; repo=$(realpath "$1"); shift
  prepare "$repo"
  local job="dispatch-queue-$(date +%m%d-%H%M%S)" runner=""
  # Each prompt waits until no vaio session is busy, so the queue also yields to jobs started by run.
  for p in "$@"; do
    runner+="until [ \"\$(claude agents --json | jq '[.[] | select(.status==\"busy\")] | length')\" = 0 ]; do sleep 60; done"$'\n'
    runner+="$(launch_cmd "$repo" "$p" "$p")"$'\n'"sleep 120"$'\n'
  done
  ssh "$HOST" "mkdir -p ~/dispatch-logs && cat > ~/dispatch-logs/$job.sh" <<<"$runner"
  ssh "$HOST" "tmux new-session -d -s $job \"bash -l ~/dispatch-logs/$job.sh > ~/dispatch-logs/$job.log 2>&1\""
  echo "$job queued ${#} prompt(s) on $HOST (tmux session $job)"
}

cmd_status() {
  agents_json | jq -r --argjson now "$(date +%s)" '.[] | "\(.id // .sessionId[:8])  \(.status)/\(.state // "-")  \((($now - .startedAt/1000) / 60 | floor))m  \(.name)"' | while read -r id rest; do
    url=$(remote "claude logs $id 2>/dev/null | grep -o 'https://claude.ai/code/session_[A-Za-z0-9]*' | tail -1" || true)
    echo "$id  $rest  ${url:-}"
  done
  remote "tmux ls -F '#{session_name}' 2>/dev/null | grep '^dispatch-' | sed 's/^/tmux: /'" || true
}

cmd_clean() {
  agents_json | jq -r '.[] | select(.kind=="background" and .status=="idle") | .id' | while read -r id; do
    remote "claude stop $id" && echo "stopped $id"
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
  run|queue) on_vaio && { echo "run/queue are for mouse; vaio is the worker" >&2; exit 1; } ;;
esac

case "${1:-}" in
  run) shift; [[ $# -eq 2 ]] || { echo "usage: dispatch.sh run <repo> <prompt>" >&2; exit 1; }; cmd_run "$@" ;;
  queue) shift; [[ $# -ge 2 ]] || { echo "usage: dispatch.sh queue <repo> <prompt>..." >&2; exit 1; }; cmd_queue "$@" ;;
  status) cmd_status ;;
  clean) cmd_clean ;;
  res) cmd_res ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
