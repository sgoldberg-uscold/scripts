#!/usr/bin/env bash

set -u

server_name="BE"
wlp_home="${WLP_HOME:-$HOME/Documents/Projects/ALL_CONFIGS/wlp}"
server_command="$wlp_home/bin/server"
lock_file="$wlp_home/usr/servers/$server_name/workarea/.sLock"

if [[ ! -x "$server_command" ]]; then
    echo "Liberty server command is not executable: $server_command" >&2
    exit 1
fi

status_output="$("$server_command" status "$server_name" 2>&1)"
status_code=$?

if [[ $status_code -eq 0 ]]; then
    echo "$status_output"
    echo "Stopping Liberty server $server_name..."

    if ! "$server_command" stop "$server_name" "$@"; then
        echo "Liberty could not stop server $server_name." >&2
        exit 1
    fi

    status_output="$("$server_command" status "$server_name" 2>&1)"
    status_code=$?
fi

if [[ $status_code -eq 0 ]]; then
    echo "Server $server_name is still running after the stop command." >&2
    exit 1
fi

if [[ "$status_output" != *"Server $server_name is not running."* ]]; then
    echo "$status_output" >&2
    echo "Unable to confirm that server $server_name stopped; the lock file was not removed." >&2
    exit 1
fi

if [[ -e "$lock_file" ]]; then
    if command -v lsof >/dev/null 2>&1 && lsof "$lock_file" >/dev/null 2>&1; then
        echo "The server lock is still held by a process: $lock_file" >&2
        exit 1
    fi

    rm "$lock_file"
    echo "Removed stale Liberty lock: $lock_file"
fi

echo "Liberty server $server_name is stopped."
