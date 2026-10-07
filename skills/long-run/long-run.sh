#!/usr/bin/env bash
# Run a long, Claude-free job (measurement / post-deploy watch) on the worker host (vaio) so it survives mouse shutting down,
# and report into an existing issue/PR: a summary comment every --every, a final one at the end, then the needs-answer label.
# Run it on any host: off the worker it copies --sync files into the worker's checkout and forwards itself over ssh.
#   long-run.sh start <project> --to <issue/PR#> --for 24h [--every 3h] --summary '<cmd>' [--sync <path>]... [--dry] -- <cmd...>
#   long-run.sh ls                 running and finished jobs
#   long-run.sh log <unit>         tail of the job's output and the supervisor journal
#   long-run.sh stop <unit>        stop the job; a final comment still gets posted
# <project> is a name in ~/.claude/skills/autopilot/projects.conf. Commands run with cwd = that checkout, under a login shell.
# --dry writes the comments to the job's state dir instead of posting them and adds no label (for testing).
set -uo pipefail

HOST=vaio
PROJECTS_CONF=$HOME/.claude/skills/autopilot/projects.conf
STATE=$HOME/.local/state/long-run
SELF=$HOME/.claude/skills/long-run/long-run.sh

die() { echo "long-run: $*" >&2; exit 1; }
project_path() { local p; p=$(awk -v n="$1" '$1 == n {print $2}' "$PROJECTS_CONF"); [[ -n $p ]] || die "unknown project $1 (define it in $PROJECTS_CONF)"; echo "${p/#\~/$HOME}"; }
to_seconds() {
  [[ $1 =~ ^([0-9]+)([smh])$ ]] || die "bad duration '$1' (use e.g. 90s, 30m, 3h)"
  local n=${BASH_REMATCH[1]}
  case ${BASH_REMATCH[2]} in s) echo "$n" ;; m) echo $((n * 60)) ;; h) echo $((n * 3600)) ;; esac
}
fmt_elapsed() { local s=$1; printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60)); }

# Off the worker: push --sync files into the worker's checkout (scratch scripts are gitignored, so they never arrive by git),
# pull ~/.claude there so it runs the same version of this script, then forward.
if [[ "$(hostname)" != ${HOST}* ]]; then
  if [[ ${1:-} == start ]]; then
    project=${2:-}; [[ -n $project ]] || die "start needs <project>"
    remote_dir=$(awk -v n="$project" '$1 == n {print $2}' "$PROJECTS_CONF")
    [[ -n $remote_dir ]] || die "unknown project $project (define it in $PROJECTS_CONF)"
    local_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run start from inside the $project checkout"
    args=("$@")
    for ((i = 0; i < ${#args[@]}; i++)); do
      [[ ${args[i]} == -- ]] && break
      if [[ ${args[i]} == --sync ]]; then
        f=${args[i + 1]:-}; [[ -f $local_root/$f ]] || die "--sync $f: not found under $local_root"
        ssh "$HOST" "mkdir -p $(printf %q "${remote_dir#\~/}/$(dirname "$f")")" || die "ssh $HOST failed"
        scp -q "$local_root/$f" "$HOST:${remote_dir#\~/}/$f" || die "scp $f failed"
      fi
    done
  fi
  ssh "$HOST" "git -C ~/.claude pull -q --ff-only" >/dev/null 2>&1 || echo "long-run: could not pull ~/.claude on $HOST; running its current copy" >&2
  exec ssh "$HOST" "bash -lc $(printf %q "$(printf '%q ' "$SELF" "$@")")"
fi

cmd_start() {
  local project=${1:-}; shift || true
  [[ -n $project ]] || die "start needs <project>"
  local to="" for="" every="" summary="" dry=""
  while [[ $# -gt 0 && $1 != -- ]]; do
    case $1 in
      --to) to=$2; shift 2 ;;
      --for) for=$2; shift 2 ;;
      --every) every=$2; shift 2 ;;
      --summary) summary=$2; shift 2 ;;
      --sync) shift 2 ;;
      --dry) dry=1; shift ;;
      *) die "unknown option $1" ;;
    esac
  done
  [[ ${1:-} == -- ]] && shift
  [[ $# -gt 0 ]] || die "missing the job command after --"
  [[ $to =~ ^[0-9]+$ ]] || die "--to <issue/PR#> is required: results nobody reads are not worth measuring"
  [[ -n $summary ]] || die "--summary '<cmd>' is required: it is what the comments are made of"
  [[ -n $for ]] || die "--for <duration> is required"
  to_seconds "$for" >/dev/null; [[ -z $every ]] || to_seconds "$every" >/dev/null

  local dir; dir=$(project_path "$project")
  [[ -d $dir/.git ]] || die "$dir is not a checkout on $(hostname)"
  local target
  target=$(cd "$dir" && gh api "repos/{owner}/{repo}/issues/$to" --jq '"\(if .pull_request then "PR" else "Issue" end) #\(.number) [\(.state)] \(.title)"' 2>&1) \
    || die "--to $to: not found in $(cd "$dir" && gh repo view --json nameWithOwner -q .nameWithOwner): $target"
  local unit="long-run-$project-$to-$(date +%m%d%H%M)"
  mkdir -p "$STATE/$unit"
  printf 'project=%q\nto=%q\nfor=%q\nevery=%q\nsummary=%q\ncmd=%q\ndry=%q\nstarted=%q\n' \
    "$project" "$to" "$for" "$every" "$summary" "$*" "$dry" "$(date '+%F %T')" > "$STATE/$unit/meta"

  # KillMode=mixed: `stop` sends TERM to the supervisor only, so it can stop the job and still post the final comment.
  # Lowest priority on the worker: under contention these jobs slow down (CPU share, memory reclaimed to swap first)
  # instead of starving autopilot sessions and nightly batches, however many of them pile up.
  systemd-run --user --unit="$unit" --collect -p KillMode=mixed -p TimeoutStopSec=90 \
    -p CPUWeight=20 -p MemoryHigh=512M \
    bash -lc "exec $(printf '%q ' "$SELF" _supervise "$unit")" >/dev/null 2>&1 || die "systemd-run failed"
  echo "$unit"
  echo "started on $(hostname)${dry:+ (dry: comments go to $STATE/$unit/comments.md)}: for $for${every:+, every $every}"
  echo "reports to: $target"
}

post() {
  local unit=$1 title=$2 final=$3 body
  body=$(mktemp)
  {
    echo "## $title"
    echo
    local out rc
    out=$(cd "$dir" && bash -c "$summary" 2>&1); rc=$?
    if [[ $rc -eq 0 && -n $out ]]; then
      echo "$out"
    else
      echo "集計コマンドが失敗しました（exit $rc）。"
      echo; echo '```'; echo "${out:0:20000}"; echo '```'
    fi
    if [[ $final == 1 && -n ${job_failed:-} && -s $STATE/$unit/job.log ]]; then
      echo; echo "<details><summary>job output (tail)</summary>"; echo; echo '```'
      tail -n 40 "$STATE/$unit/job.log"; echo '```'; echo "</details>"
    fi
    echo; echo "<sub>long-run \`$unit\` on $(hostname)</sub>"
  } > "$body"
  if [[ -n $dry ]]; then
    { cat "$body"; echo; echo "---"; } >> "$STATE/$unit/comments.md"
  else
    gh api "repos/$slug/issues/$to/comments" -F body=@"$body" >/dev/null \
      || echo "$(date '+%F %T') comment failed" >> "$STATE/$unit/supervisor.log"
  fi
  rm -f "$body"
}

cmd_supervise() {
  local unit=$1
  # shellcheck disable=SC1090
  source "$STATE/$unit/meta"
  dir=$(project_path "$project")
  cd "$dir" || exit 1
  slug=$(gh repo view --json nameWithOwner -q .nameWithOwner) || { echo "gh repo view failed" >> "$STATE/$unit/supervisor.log"; exit 1; }
  local start; start=$(date +%s)
  local deadline=$((start + $(to_seconds "$for")))
  local step=0 next=0
  if [[ -n $every ]]; then step=$(to_seconds "$every"); next=$((start + step)); fi

  setsid bash -c "$cmd" > "$STATE/$unit/job.log" 2>&1 < /dev/null &
  local pid=$!
  local stopped="" reason="completed"
  trap 'stopped=1' TERM

  while kill -0 "$pid" 2>/dev/null; do
    local now; now=$(date +%s)
    if [[ -n $stopped ]]; then reason="stopped"; break; fi
    if (( now >= deadline )); then reason="time limit ($for)"; break; fi
    if (( step > 0 && now >= next )); then
      post "$unit" "途中経過（$(fmt_elapsed $((now - start))) / $for）" 0
      next=$((next + step))
    fi
    sleep 20 & wait $!
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null; sleep 5; kill -KILL -- "-$pid" 2>/dev/null
  fi
  wait "$pid" 2>/dev/null; job_rc=$?
  if [[ $reason == completed ]]; then
    reason="completed, exit $job_rc"
    [[ $job_rc -ne 0 ]] && job_failed=1
  fi
  post "$unit" "最終結果（$(fmt_elapsed $(($(date +%s) - start)))、$reason）" 1
  [[ -n $dry ]] || gh api "repos/$slug/issues/$to/labels" -f "labels[]=needs-answer" >/dev/null \
    || echo "$(date '+%F %T') label failed" >> "$STATE/$unit/supervisor.log"
}

cmd_ls() {
  [[ -d $STATE ]] || { echo "no jobs"; return; }
  local u state
  for u in $(ls -t "$STATE"); do
    [[ -f $STATE/$u/meta ]] || continue
    state=$(systemctl --user is-active "$u" 2>/dev/null)
    ( source "$STATE/$u/meta"; printf '%-40s %-9s %s #%s for %s%s since %s\n  %s\n' "$u" "$state" "$project" "$to" "$for" "${every:+ every $every}" "$started" "$cmd" )
  done
}

cmd_log() {
  local unit=${1:-}; [[ -d $STATE/$unit ]] || die "unknown unit $unit (see ls)"
  echo "== job.log (tail)"; tail -n 30 "$STATE/$unit/job.log" 2>/dev/null
  [[ -f $STATE/$unit/supervisor.log ]] && { echo "== supervisor.log"; cat "$STATE/$unit/supervisor.log"; }
  echo "== journal"; journalctl --user -u "$unit" -n 20 --no-pager 2>/dev/null
}

cmd_stop() {
  local unit=${1:-}; [[ -d $STATE/$unit ]] || die "unknown unit $unit (see ls)"
  systemctl --user stop "$unit" && echo "stopped $unit (final comment posted by the supervisor)"
}

case ${1:-} in
  start) shift; cmd_start "$@" ;;
  _supervise) shift; cmd_supervise "$@" ;;
  ls) cmd_ls ;;
  log) shift; cmd_log "$@" ;;
  stop) shift; cmd_stop "$@" ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
