#!/usr/bin/env bash
# integrate.sh — orchestrator's view of the lanes, and the assembly merge.
#
# Run from the orchestrator's clone of the repo (the host, not a worker VM).
#
# Usage:
#   integrate.sh status                 # every lane/* branch: last commit,
#                                       # folder drift, files changed
#   integrate.sh merge [target-branch]  # fetch all lane/* and octopus-merge
#                                       # them into an integration branch
#                                       # (default: integration/build)
#
# Disjoint lane folders make the merge itself conflict-free by construction;
# if the merge DOES conflict, a lane drifted outside its folder — run status
# to find which, and fix the lane before assembling.
set -euo pipefail

MODE="${1:-status}"
BASE="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo main)"

git fetch origin --prune '+refs/heads/lane/*:refs/remotes/origin/lane/*' 2>/dev/null || git fetch origin --prune

lanes() { git for-each-ref --format='%(refname:short)' refs/remotes/origin/lane/ | sed 's|^origin/||'; }

case "$MODE" in
  status)
    FOUND=0
    for BR in $(lanes); do
      FOUND=1
      LANE_NAME="${BR#lane/}"
      LANE_DIR="workstreams/$LANE_NAME"
      echo "== $BR"
      git log -1 --format='   %h %ad %s' --date=relative "origin/$BR"
      CHANGED="$(git diff --name-only "origin/$BASE...origin/$BR" || true)"
      N_TOTAL="$(echo "$CHANGED" | grep -c . || true)"
      DRIFT="$(echo "$CHANGED" | grep -v "^$LANE_DIR/" || true)"
      echo "   files changed vs $BASE: $N_TOTAL"
      if [ -n "$DRIFT" ]; then
        echo "   DRIFT outside $LANE_DIR/:"
        echo "$DRIFT" | sed 's/^/     /'
      else
        echo "   clean: all changes inside $LANE_DIR/"
      fi
    done
    [ "$FOUND" -eq 1 ] || echo "no lane/* branches on origin yet"
    ;;
  merge)
    TARGET="${2:-integration/build}"
    LANE_REFS=()
    for BR in $(lanes); do LANE_REFS+=("origin/$BR"); done
    [ "${#LANE_REFS[@]}" -gt 0 ] || { echo "no lane/* branches to merge" >&2; exit 1; }
    git checkout -B "$TARGET" "origin/$BASE"
    echo "merging: ${LANE_REFS[*]}"
    git merge --no-ff "${LANE_REFS[@]}" \
      -m "Assemble lanes into $TARGET

$(printf '  - %s\n' "${LANE_REFS[@]}")"
    echo
    echo "lanes merged into $TARGET — now wire the seams (see references/integration.md),"
    echo "build the whole product, and push with: git push -u origin $TARGET"
    ;;
  *)
    echo "usage: $0 {status|merge [target-branch]}" >&2
    exit 2
    ;;
esac
