#!/usr/bin/env bash
# Run a non-interactive Claude job on vaio, detached in tmux so it survives mouse sleeping or changing networks.
#   dispatch.sh run <repo-path> <prompt>   e.g. dispatch.sh run ~/repo/xchain-arb "/issue-to-pr 3981"
#   dispatch.sh status                      running jobs + last log lines
#   dispatch.sh log <job>                   follow a job's log
set -euo pipefail

HOST=vaio
LOG_DIR='~/dispatch-logs'
MAX_JOBS=1

running_jobs() { ssh "$HOST" "tmux ls -F '#{session_name}' 2>/dev/null | grep '^dispatch-' || true"; }

cmd_status() {
  local jobs; jobs=$(running_jobs)
  echo "running: ${jobs:-none}"
  ssh "$HOST" "ls -t $LOG_DIR/*.log 2>/dev/null | head -3 | while read f; do echo \"== \$f\"; tail -c 600 \"\$f\"; echo; done"
}

cmd_run() {
  local repo prompt
  repo=$(realpath "$1"); prompt="$2"
  local n; n=$(running_jobs | grep -c . || true)
  if (( n >= MAX_JOBS )); then echo "vaio busy ($n job(s) running). Run on mouse or wait." >&2; exit 2; fi

  # Memory dir name is the project path with / and . replaced by -, identical on both machines because repos live at the same path.
  local mem="$HOME/.claude/projects/$(echo "$repo" | sed 's#[/.]#-#g')/memory/"
  if [[ -d "$mem" ]]; then
    ssh "$HOST" "mkdir -p '$mem'"
    rsync -a --delete "$mem" "$HOST:$mem"
  fi

  ssh "$HOST" "git -C ~/.claude pull --ff-only -q && git -C '$repo' pull --ff-only -q"

  local job="dispatch-$(date +%m%d-%H%M%S)"
  # Ship the prompt and command as a runner file so arbitrary quotes in the prompt survive ssh + tmux.
  { printf 'cd %q\n' "$repo"
    printf 'claude -p %q --permission-mode bypassPermissions --output-format stream-json --verbose\n' "$prompt"
  } | ssh "$HOST" "mkdir -p $LOG_DIR && cat > $LOG_DIR/$job.sh"
  ssh "$HOST" "tmux new-session -d -s $job \"bash -lc 'bash $LOG_DIR/$job.sh > $LOG_DIR/$job.log 2>&1'\""
  echo "$job started on $HOST (log: $LOG_DIR/$job.log)"
}

case "${1:-}" in
  run) shift; [[ $# -eq 2 ]] || { echo "usage: dispatch.sh run <repo-path> <prompt>" >&2; exit 1; }; cmd_run "$@" ;;
  status) cmd_status ;;
  log) ssh -t "$HOST" "tail -f $LOG_DIR/$2.log" ;;
  *) sed -n '2,6p' "$0"; exit 1 ;;
esac
