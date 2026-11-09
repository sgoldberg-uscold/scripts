#!/bin/zsh
# logmark.sh mark  [rf|be] : remember the current end of the server log
# logmark.sh check [rf|be] : print exceptions/errors written since the mark
# The server defaults to rf (RF-BE). Each server keeps its own mark file.
# Set LIBERTY_SERVERS_DIR to your Liberty servers folder (the one holding BE and RF-BE),
# e.g. export LIBERTY_SERVERS_DIR=<projects>/ALL_CONFIGS/wlp/usr/servers
SERVERS=${LIBERTY_SERVERS_DIR:?set LIBERTY_SERVERS_DIR to your Liberty servers folder (the one holding BE and RF-BE)}
USAGE="usage: logmark.sh mark|check [rf|be]"
SERVER=${2:-rf}
case $SERVER in
  rf) LOG=$SERVERS/RF-BE/logs/ewms-rf-be.log;;
  be) LOG=$SERVERS/BE/logs/ewms.log;;
  *) echo $USAGE; exit 1;;
esac
MARK=${0:A:h}/logmark-$SERVER.txt
case $1 in
  mark) wc -l < $LOG | tr -d ' ' > $MARK; echo "marked $LOG at line $(cat $MARK)";;
  check)
    from=$(( $(cat $MARK) + 1 ))
    echo "new log lines: $(( $(wc -l < $LOG) - from + 1 ))"
    tail -n +$from $LOG | grep -n -E "NullPointerException|Exception|ERROR" | cut -c1-240 | head -20
    echo "NPE count: $(tail -n +$from $LOG | grep -c NullPointerException)";;
  *) echo $USAGE; exit 1;;
esac
