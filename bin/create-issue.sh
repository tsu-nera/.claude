#!/usr/bin/env bash
# Sole entry point for creating GitHub issues (raw `gh issue create` is denied by a PreToolUse hook).
# Enforces mechanically what the create-issue skill asks for, so a skipped skill read still fails loudly.
set -euo pipefail

MODE="" REPO="" TITLE="" BODY_FILE="" LABELS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --label) LABELS+=("$2"); shift 2 ;;
    *) echo "create-issue.sh: unknown argument: $1" >&2; exit 1 ;;
  esac
done

die() { echo "create-issue.sh: $1" >&2; exit 1; }

[[ "$MODE" == "ready" || "$MODE" == "draft" ]] || die "--mode must be 'ready' or 'draft' (see the create-issue skill Step 0)"
[[ -n "$TITLE" ]] || die "--title is required"
[[ -n "$BODY_FILE" ]] || die "--body-file is required (do not inline the body on the command line)"
[[ -f "$BODY_FILE" ]] || die "--body-file not found: $BODY_FILE"
[[ ${#LABELS[@]} -gt 0 ]] || die "--label is required"

[[ -n "$REPO" ]] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

has_label() { local l; for l in "${LABELS[@]}"; do [[ "$l" == "$1" ]] && return 0; done; return 1; }

if [[ "$MODE" == "draft" ]]; then
  has_label inbox || die "draft mode requires --label inbox"
else
  grep -q '^## Acceptance Criteria' "$BODY_FILE" || die "ready mode requires a '## Acceptance Criteria' section"
  grep -q '^## 変更対象' "$BODY_FILE" || die "ready mode requires a '## 変更対象' section"
  grep -q '^autopilot:' "$BODY_FILE" || die "ready mode requires an 'autopilot: ...' verdict line (see references/ready.md Step 4)"
  # autopilot is a scheduling label for the Friday batch: it must never ride on an issue that
  # still names a blocker, or the queue stops being order-independent.
  if has_label autopilot && grep -qiE '(blocker|blocked by|待ち|依存)' "$BODY_FILE"; then
    echo "create-issue.sh: WARNING: --label autopilot on a body mentioning a blocker. Confirm the queue stays order-independent." >&2
  fi
fi

ARGS=(--repo "$REPO" --title "$TITLE" --body-file "$BODY_FILE")
for l in "${LABELS[@]}"; do ARGS+=(--label "$l"); done
exec gh issue create "${ARGS[@]}"
