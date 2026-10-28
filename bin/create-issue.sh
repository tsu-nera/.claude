#!/usr/bin/env bash
# Sole entry point for creating GitHub issues (raw `gh issue create` is denied by a PreToolUse hook).
# Enforces mechanically what the create-issue skill asks for, so a skipped skill read still fails loudly.
set -euo pipefail

REPO="" TITLE="" BODY_FILE="" LABELS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    --label) LABELS+=("$2"); shift 2 ;;
    *) echo "create-issue.sh: unknown argument: $1" >&2; exit 1 ;;
  esac
done

die() { echo "create-issue.sh: $1" >&2; exit 1; }

[[ -n "$TITLE" ]] || die "--title is required"
[[ -n "$BODY_FILE" ]] || die "--body-file is required (do not inline the body on the command line)"
[[ -f "$BODY_FILE" ]] || die "--body-file not found: $BODY_FILE"
[[ ${#LABELS[@]} -gt 0 ]] || die "--label is required"

[[ -n "$REPO" ]] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

has_label() { local l; for l in "${LABELS[@]}"; do [[ "$l" == "$1" ]] && return 0; done; return 1; }

grep -q '^## Acceptance Criteria' "$BODY_FILE" || die "a '## Acceptance Criteria' section is required (an issue must state what to do)"
grep -q '^## 変更対象' "$BODY_FILE" || die "a '## 変更対象' section is required (an issue must state what to do)"
grep -q '^autopilot:' "$BODY_FILE" || die "an 'autopilot: ...' verdict line is required (see references/ready.md Step 4)"
# autopilot marks an issue the unattended drain may pick in any order: it must never ride on an issue that
# still names a blocker, or the queue stops being order-independent.
if has_label autopilot && grep -qiE '(blocker|blocked by|待ち|依存)' "$BODY_FILE"; then
  echo "create-issue.sh: WARNING: --label autopilot on a body mentioning a blocker. Confirm the queue stays order-independent." >&2
fi

ARGS=(--repo "$REPO" --title "$TITLE" --body-file "$BODY_FILE")
for l in "${LABELS[@]}"; do ARGS+=(--label "$l"); done
exec gh issue create "${ARGS[@]}"
