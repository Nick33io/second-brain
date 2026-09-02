#!/usr/bin/env bash
# lane-guard.sh — keep each worker inside its own folder.
#
# Usage:
#   lane-guard.sh install <lane-path>   # from inside a worker's clone:
#                                       # installs a pre-commit hook bound to
#                                       # <lane-path> (e.g. workstreams/api)
#   lane-guard.sh check <lane-path>     # what the hook runs: fails if any
#                                       # staged file is outside <lane-path>
#
# The boundary is the whole point of the multi-VM workflow: a lane that leaks
# into another folder produces merge conflicts in Phase 5 and invisible
# coupling before that. contracts/ stays readable but never writable from a
# worker — contract changes go through the orchestrator.
set -euo pipefail

usage() { echo "usage: $0 {install|check} <lane-path>" >&2; exit 2; }
[ "$#" -eq 2 ] || usage
MODE="$1"
LANE="${2%/}"

case "$MODE" in
  install)
    GIT_DIR="$(git rev-parse --git-dir)"
    HOOK="$GIT_DIR/hooks/pre-commit"
    SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    printf '#!/usr/bin/env bash\nexec "%s" check "%s"\n' "$SELF" "$LANE" > "$HOOK"
    chmod +x "$HOOK"
    echo "lane guard installed: commits limited to $LANE/"
    ;;
  check)
    VIOLATIONS="$(git diff --cached --name-only | grep -v "^$LANE/" || true)"
    if [ -n "$VIOLATIONS" ]; then
      echo "lane guard: commit touches files outside $LANE/ — rejected:" >&2
      echo "$VIOLATIONS" | sed 's/^/  /' >&2
      echo "If a shared contract must change, ask the orchestrator to change contracts/." >&2
      exit 1
    fi
    ;;
  *) usage ;;
esac
