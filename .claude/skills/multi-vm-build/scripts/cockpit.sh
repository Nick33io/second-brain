#!/usr/bin/env bash
# cockpit.sh — one screen, four workers.
#
# Creates (or replaces) a tmux session with:
#   window 0 "fleet"   : 2x2 grid, one pane per worker command
#   window 1 "control" : a shell on the host for the orchestrator
#
# Usage:
#   cockpit.sh <session> <cmd1> <cmd2> <cmd3> <cmd4>
#
# Examples:
#   cockpit.sh build "ssh vm1" "ssh vm2" "ssh vm3" "ssh vm4"
#   cockpit.sh build "cd ~/wt/api && exec $SHELL" "cd ~/wt/ui && exec $SHELL" \
#                    "cd ~/wt/data && exec $SHELL" "cd ~/wt/infra && exec $SHELL"
#
# Panes are titled worker-1..worker-4. If a command exits (SSH drops), the pane
# stays open so you can see why (remain-on-exit).
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "usage: $0 <session> <cmd1> <cmd2> <cmd3> <cmd4>" >&2
  exit 2
fi

SESSION="$1"; shift
CMDS=("$@")

command -v tmux >/dev/null || { echo "tmux is required" >&2; exit 1; }

tmux kill-session -t "$SESSION" 2>/dev/null || true

tmux new-session -d -s "$SESSION" -n fleet "${CMDS[0]}"
for CMD in "${CMDS[@]:1}"; do
  tmux split-window -t "$SESSION:fleet" "$CMD"
  tmux select-layout -t "$SESSION:fleet" tiled
done

for i in 0 1 2 3; do
  tmux select-pane -t "$SESSION:fleet.$i" -T "worker-$((i + 1))"
done
tmux setw -t "$SESSION:fleet" pane-border-status top
tmux setw -t "$SESSION:fleet" remain-on-exit on

tmux new-window -t "$SESSION" -n control
tmux select-window -t "$SESSION:fleet"

echo "cockpit ready: tmux attach -t $SESSION"
echo "  Ctrl-b q <n>  jump to pane n        Ctrl-b z  zoom a worker"
echo "  Ctrl-b :setw synchronize-panes on   type into all four at once"
