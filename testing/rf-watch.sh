#!/bin/zsh
# Read-only mirror of the RFClient tmux session "rf". Ctrl-C to stop.
while true; do
  frame=$(tmux capture-pane -p -t rf:0.0 2>/dev/null || echo "(tmux session rf not running)")
  print -n '\e[H\e[2J'
  print -r -- "$frame"
  print -r -- "-------------------------------- RF screen (mirror, refreshes every 0.5 s) --"
  sleep 0.5
done
