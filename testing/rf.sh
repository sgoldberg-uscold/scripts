#!/bin/zsh
# rf.sh key|text ... : send each argument to the RFClient tmux pane, then print the screen.
#   Arguments that are tmux key names (Enter, F3, F8, S-F2, BSpace...) are sent as keys;
#   anything prefixed with "t:" is sent literally (e.g. t:1305).
# rf.sh            : just print the screen.
for arg in "$@"; do
  if [[ $arg == t:* ]]; then
    tmux send-keys -t rf:0.0 -l -- "${arg#t:}"
  else
    tmux send-keys -t rf:0.0 "$arg"
  fi
  perl -e 'select(undef,undef,undef,0.4)'
done
perl -e 'select(undef,undef,undef,1.2)'
tmux capture-pane -p -t rf:0.0 | sed '/^[[:space:]]*$/d'
