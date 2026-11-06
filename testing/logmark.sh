#!/bin/zsh
# logmark.sh mark  : remember the current end of the RF-BE log
# logmark.sh check : print exceptions/errors written since the mark
LOG=~/Documents/Projects/ALL_CONFIGS/wlp/usr/servers/RF-BE/logs/ewms-rf-be.log
MARK=${0:A:h}/logmark.txt
case $1 in
  mark) wc -l < $LOG | tr -d ' ' > $MARK; echo "marked at line $(cat $MARK)";;
  check)
    from=$(( $(cat $MARK) + 1 ))
    echo "new log lines: $(( $(wc -l < $LOG) - from + 1 ))"
    tail -n +$from $LOG | grep -n -E "NullPointerException|Exception|ERROR" | cut -c1-240 | head -20
    echo "NPE count: $(tail -n +$from $LOG | grep -c NullPointerException)";;
esac
